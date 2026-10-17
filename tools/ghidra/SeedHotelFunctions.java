// Add verified original function entries to the existing analysis.
// @category HotelDusk
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import java.nio.file.*;

public class SeedHotelFunctions extends GhidraScript {
    public void run() throws Exception {
        String[] args = getScriptArgs();
        Path output = Paths.get(args[0]);
        for (int i = 1; i < args.length; i++) {
            Address address = toAddr(Long.parseUnsignedLong(args[i], 16));
            disassemble(address);
            if (getFunctionAt(address) == null)
                createFunction(address, "Original_" + args[i]);
        }
        analyzeChanges(currentProgram);
        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        for (int i = 1; i < args.length; i++) {
            Function function = getFunctionAt(toAddr(Long.parseUnsignedLong(args[i], 16)));
            if (function == null) throw new Exception("Missing function " + args[i]);
            DecompileResults result = decompiler.decompileFunction(function, 60, monitor);
            if (!result.decompileCompleted()) throw new Exception(result.getErrorMessage());
            Files.writeString(output.resolve(args[i] + ".c"),
                "/* Original address: " + args[i] + " */\n" + result.getDecompiledFunction().getC());
            println("Exported " + args[i]);
        }
        decompiler.dispose();
    }
}
