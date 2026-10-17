// Recover runtime memory placement before following original calls.
// @category HotelDusk
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.SourceType;
import java.io.ByteArrayInputStream;

public class PrepareHotelDusk extends GhidraScript {
    public void run() throws Exception {
        Memory memory = currentProgram.getMemory();
        Address base = toAddr(0x02004000L);
        // The module parameters and their marker are read from this ROM.
        long table = Integer.toUnsignedLong(memory.getInt(base.add(0xb68)));
        long end = Integer.toUnsignedLong(memory.getInt(base.add(0xb6c)));
        long data = Integer.toUnsignedLong(memory.getInt(base.add(0xb70)));
        long bss = Integer.toUnsignedLong(memory.getInt(base.add(0xb74)));
        long bssEnd = Integer.toUnsignedLong(memory.getInt(base.add(0xb78)));
        if (table != 0x020ffca0L || end != 0x020ffcb8L || data != 0x020fd6c0L)
            throw new Exception("Unexpected ARM9 module table");
        for (long entry = table; entry < end; entry += 12) {
            long address = Integer.toUnsignedLong(memory.getInt(toAddr(entry)));
            int length = memory.getInt(toAddr(entry + 4));
            int zero = memory.getInt(toAddr(entry + 8));
            byte[] bytes = new byte[length];
            memory.getBytes(toAddr(data), bytes);
            String name = "autoload_" + Long.toHexString(address);
            MemoryBlock block = memory.createInitializedBlock(name, toAddr(address),
                new ByteArrayInputStream(bytes), length, monitor, false);
            block.setExecute(true);
            if (zero > 0) memory.createUninitializedBlock(name + "_bss", toAddr(address + length), zero, false);
            data += length;
        }
        MemoryBlock main = memory.getBlock(base);
        if (main.getEnd().getOffset() >= bss) {
            memory.split(main, toAddr(bss));
            memory.removeBlock(memory.getBlock(toAddr(bss)), monitor);
        }
        memory.createUninitializedBlock("game_bss", toAddr(bss), bssEnd - bss, false);
        long[] entries = {0x02004800L,0x02029254L,0x02028268L,
            0x0203bc9cL,0x0203f57cL,0x0203fe98L,0x02054df4L,0x020551b8L,
            0x02097544L,0x02097804L,0x02097840L,0x02097914L,0x0209798cL,
            0x02097a80L,0x02097d90L,0x02097ddcL,0x02097e6cL,0x02097e94L,
            0x02097eb0L,0x020b5634L,
            0x01ff9158L};
        for (long value : entries) {
            Address address = toAddr(value);
            if (memory.contains(address)) {
                disassemble(address);
                if (getFunctionAt(address) == null) createFunction(address, "Original_" + Long.toHexString(value));
            }
        }
        println("Recovered ARM9 autoload sections and BSS");
    }
}
