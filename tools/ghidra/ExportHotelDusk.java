// Export source-addressed decompiler output for manual native reconstruction.
// @category HotelDusk
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class ExportHotelDusk extends GhidraScript {
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) throw new Exception("Output directory required");
        Path output = Paths.get(args[0]); Files.createDirectories(output);
        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        ArrayList<Function> functions = new ArrayList<>();
        FunctionIterator iterator = currentProgram.getFunctionManager().getFunctions(true);
        while (iterator.hasNext()) functions.add(iterator.next());
        // Export game control functions before SDK support routines.
        functions.sort(Comparator.comparingLong(f -> {
            long a = f.getEntryPoint().getOffset();
            return (a >= 0x02000000L && a < 0x020a0000L) ? a : a + 0x10000000L;
        }));
        ArrayList<String> index = new ArrayList<>();
        index.add("address\tname\tbytes\tstatus\tcallers");
        int completed = 0;
        for (Function function : functions) {
            monitor.checkCancelled();
            DecompileResults result = decompiler.decompileFunction(function, 45, monitor);
            String address = function.getEntryPoint().toString();
            String status = result.decompileCompleted() ? "decompiled" : "incomplete";
            String code = result.decompileCompleted() ? result.getDecompiledFunction().getC()
                : "/* " + result.getErrorMessage() + " */\n";
            Files.writeString(output.resolve(address + ".c"),
                "/* Original address: " + address + "; " + function.getName() + " */\n" + code,
                StandardCharsets.UTF_8);
            String callers = function.getCallingFunctions(monitor).stream()
                .map(f -> f.getEntryPoint().toString()).sorted().reduce((a,b) -> a + "," + b).orElse("");
            index.add(address + "\t" + function.getName() + "\t" + function.getBody().getNumAddresses()
                + "\t" + status + "\t" + callers);
            completed++;
            if (completed % 100 == 0) println("Exported " + completed + "/" + functions.size());
        }
        Files.write(output.resolve("functions.tsv"), index, StandardCharsets.UTF_8);
        decompiler.dispose();
        println("Exported " + completed + " original functions; inspect all warnings before translating");
    }
}
