import AudioToolbox
import XCTest

enum AudioTestSupport {
    static func requireAudioFilePlayer() throws {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Generator,
            componentSubType: kAudioUnitSubType_AudioFilePlayer,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard AudioComponentFindNext(nil, &description) != nil else {
            throw XCTSkip("The Apple Audio File Player audio unit is unavailable in this test environment.")
        }
    }

    static func requireAppleSampler() throws {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: kAudioUnitSubType_Sampler,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard AudioComponentFindNext(nil, &description) != nil else {
            throw XCTSkip("The Apple sampler audio unit is unavailable in this test environment.")
        }
    }
}
