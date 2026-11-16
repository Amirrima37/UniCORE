#include <windows.h>
#include <gmshc.h>
#include <cmath>
#include <iostream>
#include <stdexcept>
int main(int argc, char **argv) {
 try {
  if(argc != 2) throw std::runtime_error("Expected absolute Gmsh DLL path");
  HMODULE lib=LoadLibraryA(argv[1]);
  if(!lib) throw std::runtime_error("Cannot load Gmsh SDK");
#define API(name) auto name=reinterpret_cast<decltype(&::name)>(GetProcAddress(lib,#name)); if(!name) throw std::runtime_error(#name)
  API(gmshInitialize); API(gmshFinalize); API(gmshModelOccAddBox);
  API(gmshModelOccSynchronize); API(gmshModelOccGetMass);
  API(gmshOptionSetNumber); API(gmshModelMeshGenerate);
  API(gmshModelMeshGetElementsByType); API(gmshFree); API(gmshWrite);
  int err=0;
  auto check=[&](){if(err) throw std::runtime_error("Gmsh API error "+std::to_string(err));};
  gmshInitialize(0,nullptr,0,0,&err); check();
  int solid=gmshModelOccAddBox(0,0,0,1,2,3,-1,&err); check();
  gmshModelOccSynchronize(&err); check();
  double volume=0; gmshModelOccGetMass(3,solid,&volume,&err); check();
  if(std::abs(volume-6)>1e-10) throw std::runtime_error("OCCT volume benchmark failed");
  gmshWrite("block.step",&err); check();
  gmshOptionSetNumber("General.NumThreads",2,&err); check();
  gmshOptionSetNumber("Mesh.MeshSizeMax",0.4,&err); check();
  gmshModelMeshGenerate(3,&err); check();
  size_t *elements=nullptr,*nodes=nullptr,ne=0,nn=0;
  gmshModelMeshGetElementsByType(4,&elements,&ne,&nodes,&nn,-1,0,1,&err); check();
  if(ne==0 || nn!=ne*4) throw std::runtime_error("TET4 connectivity absent");
  gmshWrite("block.msh",&err); check();
  std::cout<<"GMSH_OCCT_SMOKE_PASS volume="<<volume<<" tet4="<<ne<<"\n";
  gmshFree(elements); gmshFree(nodes); gmshFinalize(&err); check();
  FreeLibrary(lib); return 0;
 } catch(const std::exception &e) {std::cerr<<e.what()<<"\n";return 1;}
}
