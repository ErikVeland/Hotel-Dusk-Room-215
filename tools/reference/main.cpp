// Verification-only ROM runner. The native Swift app does not use this code.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "NDS.h"
#include "Args.h"
#include "NDSCart.h"
#include "Savestate.h"
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>
#include <iomanip>
using namespace melonDS;
static std::vector<u8> readFile(const std::string& path) {
    std::ifstream f(path,std::ios::binary); if(!f)throw std::runtime_error("Cannot read "+path);
    return {std::istreambuf_iterator<char>(f),std::istreambuf_iterator<char>()};
}
static void writeFile(const std::string& path,const void* bytes,size_t count) {
    std::ofstream f(path,std::ios::binary);f.write((const char*)bytes,count);
    if(!f)throw std::runtime_error("Cannot write "+path);
}
static void image(const std::string& path,void* buffer) {
    std::ofstream f(path,std::ios::binary);f<<"P6\n256 192\n255\n";
    auto pixels=static_cast<u32*>(buffer);
    for(int i=0;i<256*192;i++){u32 p=pixels[i];char rgb[3]={(char)(p>>16),(char)(p>>8),(char)p};f.write(rgb,3);}
}
int main(int argc,char**argv) { try {
    if(argc!=3){std::cerr<<"Usage: hotel-reference ROM.nds output-directory < commands\n";return 2;}
    std::filesystem::create_directories(argv[2]);std::string output=argv[2],save=output+"/cartridge.sav";
    auto console=std::make_unique<NDS>(NDSArgs{},&save);auto& nds=*console;
    auto rom=readFile(argv[1]);auto cart=NDSCart::ParseROM(rom.data(),rom.size(),&save);
    if(!cart)throw std::runtime_error("ROM parse failed");
    if(std::filesystem::exists(save)){auto data=readFile(save);cart->SetSaveMemory(data.data(),data.size());}
    nds.SetNDSCart(std::move(cart));nds.Reset();nds.SetupDirectBoot("Hotel Dusk - Room 215.nds");
    nds.RTC.SetDateTime(2007,1,22,12,0,0);nds.Start();
    std::ofstream audio(output+"/audio.s16le",std::ios::binary),inputs(output+"/inputs.txt"),cues(output+"/audio-cues.csv");u64 frames=0,audioFrames=0;
    std::ofstream cinematic(output+"/cinematic-frames.csv");u32 cinematicBase=0;
    std::ofstream clockTrace(output+"/clock-frames.csv");u32 clockBase=0;
    clockTrace<<"frame,vtable,phase,animation,counter,hold,stage,visible,alpha,hour,minute,second,timeSlot,tick,tickSeen\n";
    cinematic<<"frame,object,handler,phase,counter\n";
    cues<<"frame,audioFrame,activeBGM,lastBGM,pauseCounter,musicMute,effectsMute\n";
    std::string lastCue;
    auto runFrame=[&] {
        nds.RunFrame();s16 samples[4096];int count=nds.SPU.ReadOutput(samples,2048);
        audio.write((char*)samples,count*4);audioFrames+=count;++frames;
        auto read16=[&](u32 a){s16 value;memcpy(&value,nds.MainRAM+(a&nds.MainRAMMask),2);return value;};
        std::ostringstream cue;cue<<read16(0x020fdd72)<<','<<read16(0x020fdd76)<<','<<read16(0x020fdd78)<<','<<int(nds.MainRAM[0xfdDB0])<<','<<int(nds.MainRAM[0xfdDB1]);
        if(cue.str()!=lastCue){lastCue=cue.str();cues<<frames<<','<<audioFrames<<','<<lastCue<<'\n';}
        if(cinematicBase) {
            auto read32=[&](u32 a){u32 v=0;if(a>=0x02000000&&a<=0x023ffffc)memcpy(&v,nds.MainRAM+(a&nds.MainRAMMask),4);return v;};
            const u32 object=read32(read32(cinematicBase+0x298));
            const u32 handler=read32(read32(object)+8);
            cinematic<<frames<<','<<std::hex<<object<<','<<handler<<std::dec<<','
                     <<(object?read16(object+4):0)<<','<<(object?read16(object+6):0)<<'\n';
        }
        if(clockBase) {
            u32 vtable;memcpy(&vtable,nds.MainRAM+(clockBase&nds.MainRAMMask),4);
            u32 tick;memcpy(&tick,nds.MainRAM+((clockBase+0x38c)&nds.MainRAMMask),4);
            clockTrace<<frames<<','<<std::hex<<vtable<<std::dec<<','<<read16(clockBase+0xc)<<','
                      <<read16(clockBase+0xe)<<','<<read16(clockBase+0x10)<<','<<read16(clockBase+0x12)<<','
                      <<read16(clockBase+0x39c)<<','<<int(nds.MainRAM[(clockBase+0x398)&nds.MainRAMMask])<<','
                      <<read16(clockBase+0x39a)<<','<<read16(clockBase+0x384)<<','<<read16(clockBase+0x386)<<','
                      <<read16(clockBase+0x388)<<','<<read16(0x0211018e)<<','<<tick<<','
                      <<int(nds.MainRAM[(clockBase+0x39e)&nds.MainRAMMask])<<'\n';
        }
    };
    std::string line;
    while(std::getline(std::cin,line)) {
        inputs<<line<<'\n';
        std::istringstream command(line);std::string op;command>>op;
        if(op.empty()||op[0]=='#')continue;
        if(op=="frames") {unsigned n;command>>n;for(unsigned i=0;i<n;i++)runFrame();}
        else if(op=="until32") {u32 address,value;unsigned limit;command>>std::hex>>address>>value>>std::dec>>limit;if(address<0x02000000||address>0x023ffffc)throw std::runtime_error("Main RAM address required");bool found=false;for(unsigned i=0;i<limit;i++){u32 actual;memcpy(&actual,nds.MainRAM+(address&nds.MainRAMMask),4);if(actual==value){found=true;break;}runFrame();}if(!found)throw std::runtime_error("Memory condition not reached");std::cout<<"matched at frame "<<frames<<std::endl;}
        else if(op=="until-nonzero32") {u32 address;unsigned limit;command>>std::hex>>address>>std::dec>>limit;if(address<0x02000000||address>0x023ffffc)throw std::runtime_error("Main RAM address required");bool found=false;for(unsigned i=0;i<limit;i++){u32 actual;memcpy(&actual,nds.MainRAM+(address&nds.MainRAMMask),4);if(actual!=0){found=true;break;}runFrame();}if(!found)throw std::runtime_error("Memory condition not reached");std::cout<<"matched at frame "<<frames<<std::endl;}
        else if(op=="keys"){u32 mask;command>>std::hex>>mask;nds.SetKeyMask(mask);}
        else if(op=="touch"){u16 x,y;command>>x>>y;nds.TouchScreen(x,y);}
        else if(op=="release")nds.ReleaseScreen();
        else if(op=="lid"){int closed;command>>closed;nds.SetLidClosed(closed!=0);}
        else if(op=="trace-cinematic") {
            command>>std::hex>>cinematicBase;
            if(!command||(cinematicBase&&(cinematicBase<0x02000000||cinematicBase>0x023ffd50)))
                throw std::runtime_error("Cinematic controller must be in main RAM");
        }
        else if(op=="trace-clock") {
            command>>std::hex>>clockBase;
            if(!command||(clockBase&&(clockBase<0x02000000||clockBase>0x023ffc5c)))
                throw std::runtime_error("Clock process must be in main RAM");
        }
        else if(op=="write8"||op=="write16"||op=="write32") {
            u32 address,value;command>>std::hex>>address>>value;
            const unsigned width=op=="write8"?1:op=="write16"?2:4;
            if(!command||address<0x02000000||address>0x02400000-width||address%width)
                throw std::runtime_error("Aligned main RAM write required");
            for(unsigned i=0;i<width;i++)nds.MainRAM[(address&nds.MainRAMMask)+i]=u8(value>>(8*i));
        }
        else if(op=="save") {std::string name;command>>name;Savestate state;nds.DoSavestate(&state);state.Finish();if(state.Error)throw std::runtime_error("State save failed");writeFile(output+"/"+name+".mln",state.Buffer(),state.Length());}
        else if(op=="load") {std::string path;std::getline(command>>std::ws,path);auto bytes=readFile(path);Savestate state(bytes.data(),bytes.size(),false);if(!nds.DoSavestate(&state)||state.Error)throw std::runtime_error("State load failed");}
        else if(op=="capture") {std::string name;command>>name;if(name.find('/')!=std::string::npos)throw std::runtime_error("Capture name must be a basename");void *top,*bottom;if(!nds.GPU.GetFramebuffers(&top,&bottom))throw std::runtime_error("Software framebuffers required");image(output+"/"+name+"-top.ppm",top);image(output+"/"+name+"-bottom.ppm",bottom);writeFile(output+"/"+name+"-ram.bin",nds.MainRAM,nds.MainRAMMask+1);std::cout<<"captured "<<name<<" frame "<<frames<<std::endl;}
        else if(op=="capture-geometry") {
            std::string name;command>>name;
            if(name.empty()||name.find('/')!=std::string::npos)throw std::runtime_error("Capture name must be a basename");
            const auto& gpu=nds.GPU.GPU3D;
            std::ofstream file(output+"/"+name+"-geometry.txt");
            file<<std::hex<<"display "<<gpu.RenderDispCnt<<" clear "<<gpu.RenderClearAttr1<<" fog "<<gpu.RenderFogColor<<'\n';
            file<<"display-a "<<nds.GPU.GPU2D_A.DispCnt<<" display-b "<<nds.GPU.GPU2D_B.DispCnt
                <<" capture "<<nds.GPU.CaptureCnt<<'\n';
            for(u32 i=0;i<gpu.RenderNumPolygons;i++) {
                const auto& polygon=*gpu.RenderPolygonRAM[i];
                file<<"polygon "<<i<<" attributes "<<polygon.Attr<<" texture "<<polygon.TexParam<<" palette "<<polygon.TexPalette<<'\n';
                for(u32 j=0;j<polygon.NumVertices;j++) {
                    const auto& vertex=*polygon.Vertices[j];
                    file<<std::dec<<"vertex "<<vertex.FinalPosition[0]<<' '<<vertex.FinalPosition[1]
                        <<" uv "<<vertex.TexCoords[0]<<' '<<vertex.TexCoords[1]
                        <<" colour "<<vertex.FinalColor[0]<<' '<<vertex.FinalColor[1]<<' '<<vertex.FinalColor[2]<<'\n'<<std::hex;
                }
            }
            if(!file)throw std::runtime_error("Cannot write geometry capture");
            std::vector<u8> texture(0x80000),palette(0x18000);
            for(u32 i=0;i<texture.size();i++)texture[i]=nds.GPU.ReadVRAMFlat_Texture<u8>(i);
            for(u32 i=0;i<palette.size();i++)palette[i]=nds.GPU.ReadVRAMFlat_TexPal<u8>(i);
            writeFile(output+"/"+name+"-texture.bin",texture.data(),texture.size());
            writeFile(output+"/"+name+"-palette.bin",palette.data(),palette.size());
        }
        else if(op=="quit")break;
        else throw std::runtime_error("Unknown command: "+op);
    }
    return 0;
} catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;} }
