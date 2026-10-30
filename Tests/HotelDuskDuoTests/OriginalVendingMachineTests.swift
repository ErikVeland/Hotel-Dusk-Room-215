import XCTest
@testable import HotelDuskDuoKit

@MainActor
final class OriginalVendingMachineTests: XCTestCase {
    private func session() throws -> OriginalPlaySession {
        let catalog = try OriginalScriptCatalog.bundled()
        var game = try OriginalGameState.newGame(defaults: .bundled(), timestamp: 0)
        game.setMap(3, previous: 2)
        try game.apply(.addInventory(id: 30))
        var runner = try OriginalEventRunner(program: catalog.loadProgram("EP1_R103"), game: game, deferArrival: true)
        runner.useItemInSearchView(30, area: 2, subarea: 1)
        var response = try XCTUnwrap(runner.searchFallback(catalog: catalog))
        for _ in 0..<30 {
            guard case .dialogue = response.phase else { break }
            response.acknowledgeDialogue()
        }
        XCTAssertEqual(response.phase, .process(id: 57))
        XCTAssertEqual(response.eventIndex, 256)
        let audio = AudioController()
        audio.isMuted = true
        let play = OriginalPlaySession(runner: response, audio: audio, catalog: catalog, puzzleSeed: { 42 })
        return play
    }

    func testChapterOneCoinsOpenTheVendingMachineWithoutHalting() throws {
        let play = try session()
        defer { play.stop() }
        XCTAssertEqual(play.runner.phase, .process(id: 57))
        XCTAssertNotNil(play.vendingMachineImage)
        XCTAssertEqual(play.vendingMachineProducts.count, 6)
    }

    private func ready(states: [UInt8] = Array(repeating: 0, count: 88),
                       random: UInt16 = 10, shifted: Bool = false) -> OriginalVendingMachineProcess {
        var process = OriginalVendingMachineProcess(randomInfo: random, shifted: shifted, itemStates: states)
        for _ in 0..<60 { process.update() }
        process.receive(.insertCoin)
        for _ in 0..<32 { process.update() }
        return process
    }

    private func purchase(_ code: Int, process: inout OriginalVendingMachineProcess) {
        process.receive(.digit(code / 10))
        process.receive(.digit(code % 10))
        process.receive(.confirm)
        for _ in 0..<180 { process.update() }
    }

    func testOriginalProductCodesReturnTheirOwnStoryResults() {
        for (code, item, result): (Int, UInt8, Int16) in [(10, 38, 4), (11, 34, 0), (12, 35, 1), (13, 36, 2)] {
            var process = ready()
            purchase(code, process: &process)
            XCTAssertEqual(process.selectedItem, item)
            XCTAssertEqual(process.result, result)
        }
    }

    func testCoinIsRequiredAndReturnClearsTheEnteredCode() {
        var process = OriginalVendingMachineProcess(randomInfo: 10, shifted: false, itemStates: Array(repeating: 0, count: 88))
        process.receive(.quit)
        for _ in 0..<60 { process.update() }
        process.receive(.digit(1))
        process.receive(.confirm)
        XCTAssertTrue(process.digits.isEmpty)
        XCTAssertNil(process.result)
        process.receive(.insertCoin)
        for _ in 0..<32 { process.update() }
        process.receive(.digit(1))
        process.receive(.digit(0))
        process.receive(.digit(9))
        XCTAssertEqual(process.digits, [1, 0])
        process.receive(.returnCoin)
        XCTAssertFalse(process.coinInserted)
        XCTAssertTrue(process.digits.isEmpty)
        process.receive(.confirm)
        XCTAssertNil(process.selectedItem)
    }

    func testUnavailableAndInvalidCodesKeepCreditForAnotherAttempt() {
        var states = [UInt8](repeating: 0, count: 88)
        states[38] = 1
        var process = ready(states: states)
        purchase(10, process: &process)
        XCTAssertTrue(process.rejectedCode)
        XCTAssertTrue(process.coinInserted)
        XCTAssertNil(process.result)
        purchase(99, process: &process)
        XCTAssertTrue(process.coinInserted)
        XCTAssertNil(process.selectedItem)
        purchase(11, process: &process)
        XCTAssertEqual(process.result, 0)
    }

    func testHiddenPrizeUsesRetainedRandomValueAndShiftedVariant() {
        for (random, shifted, item, result): (UInt16, Bool, UInt8, Int16) in [
            (10, false, 78, 5), (9, true, 79, 6)
        ] {
            var process = ready(random: random, shifted: shifted)
            purchase(51, process: &process)
            XCTAssertEqual(process.selectedItem, item)
            XCTAssertEqual(process.result, result)
        }
        var states = [UInt8](repeating: 0, count: 88)
        states[78] = 1
        var claimed = ready(states: states)
        purchase(51, process: &claimed)
        XCTAssertNil(claimed.result)
        XCTAssertNil(claimed.selectedItem)
        var wrongSeed = ready(random: 1)
        purchase(51, process: &wrongSeed)
        XCTAssertNil(wrongSeed.result)
    }

    func testSessionPurchaseAwardsChipsThroughOriginalSystemEvent261() throws {
        let play = try session()
        defer { play.stop() }
        for _ in 0..<60 { play.advanceFrame() }
        play.vendingMachineAction(.insertCoin)
        for _ in 0..<32 { play.advanceFrame() }
        play.vendingMachineAction(.digit(1))
        play.vendingMachineAction(.digit(0))
        play.vendingMachineAction(.confirm)
        for _ in 0..<180 { play.advanceFrame() }
        XCTAssertNil(play.vendingMachine)
        XCTAssertEqual(play.runner.eventIndex, 261)
        play.advanceDialogue()
        XCTAssertTrue(try play.runner.game.inventory.items.contains(38))
        XCTAssertTrue(try play.runner.game.inventory.items.contains(30))
        guard case .itemNotice(38, _) = play.runner.phase else {
            return XCTFail("The original chips award did not run: \(play.runner.phase)")
        }
    }

    func testQuitDoesNotAwardAnItem() {
        var process = ready()
        process.receive(.quit)
        for _ in 0..<60 { process.update() }
        XCTAssertEqual(process.result, 3)
        XCTAssertNil(process.selectedItem)
    }

    func testEncodedInputsReplayCreditDigitsAndPurchaseExactly() throws {
        let first = try session(), replay = try session()
        defer { first.stop(); replay.stop() }
        let inputs: [OriginalProgressInput] = [
            .frames(count: 60, microphone: 0), .vendingMachine(action: .insertCoin),
            .frames(count: 32, microphone: 0), .vendingMachine(action: .digit(1)),
            .vendingMachine(action: .digit(2)), .vendingMachine(action: .confirm),
            .frames(count: 180, microphone: 0), .advanceDialogue
        ]
        let decoded = try JSONDecoder().decode([OriginalProgressInput].self, from: JSONEncoder().encode(inputs))
        for input in inputs { first.applyProgressInput(input) }
        for input in decoded { replay.applyProgressInput(input) }
        XCTAssertEqual(replay.runner.phase, first.runner.phase)
        XCTAssertEqual(OriginalScriptCatalog.digest(replay.runner.game.snapshot), OriginalScriptCatalog.digest(first.runner.game.snapshot))
        XCTAssertTrue(try replay.runner.game.inventory.items.contains(35))
    }
}
