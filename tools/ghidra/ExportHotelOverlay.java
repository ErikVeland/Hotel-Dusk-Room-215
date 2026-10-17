// Load one original overlay alongside the already analyzed ARM9 image.
// Run with -readOnly so shared overlay addresses never contaminate the project.
// @category HotelDusk
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import java.nio.file.*;
import java.io.*;
import java.util.*;
public class ExportHotelOverlay extends GhidraScript {
 public void run() throws Exception {
  String[] a=getScriptArgs(); byte[] bytes=Files.readAllBytes(Paths.get(a[0]));
  long base=Long.parseUnsignedLong(a[1],16), bss=Long.parseLong(a[2]);
  long init=Long.parseUnsignedLong(a[3],16), initEnd=Long.parseUnsignedLong(a[4],16);
  Path output=Paths.get(a[5]);Files.createDirectories(output);
  Memory memory=currentProgram.getMemory();
  MemoryBlock block=memory.createInitializedBlock("original_overlay",toAddr(base),new ByteArrayInputStream(bytes),bytes.length,monitor,false);
  block.setExecute(true);
  if(bss>0)memory.createUninitializedBlock("overlay_bss",toAddr(base+bytes.length),bss,false);
  ArrayList<Long> entries=new ArrayList<>();entries.add(base);
  for(long p=init;p<initEnd;p+=4)entries.add(Integer.toUnsignedLong(memory.getInt(toAddr(p))));
  // Consecutive original function pointers expose virtual method tables.
  // These are analysis candidates; exported code still requires verification.
  java.nio.ByteBuffer raw=java.nio.ByteBuffer.wrap(bytes).order(java.nio.ByteOrder.LITTLE_ENDIAN);
  TreeSet<Long> candidates=new TreeSet<>(entries);
  for(int p=0;p+12<=bytes.length;p+=4){
   boolean run=true;long[] values=new long[3];
   for(int j=0;j<3;j++){values[j]=Integer.toUnsignedLong(raw.getInt(p+4*j));if(values[j]<base||values[j]>=base+bytes.length||(values[j]&3)!=0)run=false;}
   if(run)for(long value:values)candidates.add(value);
  }
  for(long value:candidates){Address entry=toAddr(value);disassemble(entry);if(getFunctionAt(entry)==null)createFunction(entry,"Overlay_"+Long.toHexString(value));}
  analyzeChanges(currentProgram);
  DecompInterface decompiler=new DecompInterface();decompiler.openProgram(currentProgram);
  ArrayList<String> index=new ArrayList<>();index.add("address\tname\tbytes\tstatus");
  FunctionIterator functions=currentProgram.getFunctionManager().getFunctions(toAddr(base),true);
  while(functions.hasNext()){
   monitor.checkCancelled();Function f=functions.next();long address=f.getEntryPoint().getOffset();if(address>=base+bytes.length)break;
   DecompileResults result=decompiler.decompileFunction(f,45,monitor);
   String code=result.decompileCompleted()?result.getDecompiledFunction().getC():"/* "+result.getErrorMessage()+" */";
   Files.writeString(output.resolve(String.format("%08x.c",address)),"/* Original overlay address: "+f.getEntryPoint()+" */\n"+code);
   index.add(f.getEntryPoint()+"\t"+f.getName()+"\t"+f.getBody().getNumAddresses()+"\t"+result.decompileCompleted());
  }
  Files.write(output.resolve("functions.tsv"),index);decompiler.dispose();println("Exported overlay functions: "+(index.size()-1));
 }
}
