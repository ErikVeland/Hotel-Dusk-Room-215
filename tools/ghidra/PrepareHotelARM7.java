// Recreate ARM7 autoload placement from its original startup table.
// @category HotelDusk
import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.*;
import ghidra.program.model.address.*;
import java.io.*;
public class PrepareHotelARM7 extends GhidraScript {
 public void run() throws Exception {
  Memory m=currentProgram.getMemory();long base=0x02380000L;
  long table=Integer.toUnsignedLong(m.getInt(toAddr(base+0x198)));
  long end=Integer.toUnsignedLong(m.getInt(toAddr(base+0x19c)));
  long source=Integer.toUnsignedLong(m.getInt(toAddr(base+0x1a0)));
  long bss=Integer.toUnsignedLong(m.getInt(toAddr(base+0x1a4)));
  long bssEnd=Integer.toUnsignedLong(m.getInt(toAddr(base+0x1a8)));
  for(long p=table;p<end;p+=12){
   long address=Integer.toUnsignedLong(m.getInt(toAddr(p)));int length=m.getInt(toAddr(p+4));int zero=m.getInt(toAddr(p+8));
   byte[] bytes=new byte[length];m.getBytes(toAddr(source),bytes);
   MemoryBlock block=m.createInitializedBlock("autoload_"+Long.toHexString(address),toAddr(address),new ByteArrayInputStream(bytes),length,monitor,false);block.setExecute(true);
   if(zero>0)m.createUninitializedBlock("autoload_bss_"+Long.toHexString(address),toAddr(address+length),zero,false);
   source+=length;
  }
  // Keep the tiny startup loader; its relocated data is not live code here.
  MemoryBlock main=m.getBlock(toAddr(base));m.split(main,toAddr(base+0x1b0));m.removeBlock(m.getBlock(toAddr(base+0x1b0)),monitor);
  if(bssEnd>bss)m.createUninitializedBlock("arm7_bss",toAddr(bss),bssEnd-bss,false);
  long[] entries={base,0x037f8468L,0x037fb9d4L};
  for(long value:entries){Address a=toAddr(value);disassemble(a);if(getFunctionAt(a)==null)createFunction(a,"Original_"+Long.toHexString(value));}
 }
}
