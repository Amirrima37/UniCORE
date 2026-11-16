#include <nlohmann/json.hpp>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRepGProp.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_GTransform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <STEPControl_Reader.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_ListIteratorOfListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Iterator.hxx>
#include <GProp_GProps.hxx>
#include <Bnd_Box.hxx>
#include <gp_Trsf.hxx>
#include <gp_GTrsf.hxx>
#include <Standard_Version.hxx>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <cmath>
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <bcrypt.h>
using J=nlohmann::json; namespace fs=std::filesystem;
static std::string sha256(const fs::path& path){
 if(!fs::is_regular_file(path)||fs::file_size(path)>64*1024*1024)throw std::runtime_error("Input/output file limit");
 BCRYPT_ALG_HANDLE algorithm=nullptr;BCRYPT_HASH_HANDLE hash=nullptr;
 auto check=[](NTSTATUS status){if(status<0)throw std::runtime_error("Native SHA-256 failure");};
 try{
  check(BCryptOpenAlgorithmProvider(&algorithm,BCRYPT_SHA256_ALGORITHM,nullptr,0));ULONG size=0,returned=0;check(BCryptGetProperty(algorithm,BCRYPT_OBJECT_LENGTH,reinterpret_cast<PUCHAR>(&size),sizeof(size),&returned,0));
  std::vector<UCHAR> object(size),buffer(65536),digest(32);check(BCryptCreateHash(algorithm,&hash,object.data(),size,nullptr,0,0));std::ifstream input(path,std::ios::binary);
  if(!input)throw std::runtime_error("Cannot hash native input");
  while(input){input.read(reinterpret_cast<char*>(buffer.data()),buffer.size());if(input.gcount()>0)check(BCryptHashData(hash,buffer.data(),static_cast<ULONG>(input.gcount()),0));}
  if(input.bad())throw std::runtime_error("Native hash input read failed");check(BCryptFinishHash(hash,digest.data(),digest.size(),0));
  BCryptDestroyHash(hash);hash=nullptr;BCryptCloseAlgorithmProvider(algorithm,0);algorithm=nullptr;std::string result;for(auto b:digest){result+="0123456789abcdef"[b>>4];result+="0123456789abcdef"[b&15];}return result;
 }catch(...){if(hash)BCryptDestroyHash(hash);if(algorithm)BCryptCloseAlgorithmProvider(algorithm,0);throw;}
}
static fs::path local(const std::string& name) {
 if(name.empty()||fs::path(name).filename()!=fs::path(name)||name=="."||name=="..") throw std::runtime_error("Job-local filename required");
 auto p=fs::current_path()/name;
 if(fs::exists(p)&&fs::is_symlink(fs::symlink_status(p))) throw std::runtime_error("Symlink rejected");
 return p;
}
static TopoDS_Shape read(const std::string& name) {
 auto p=local(name);if(fs::file_size(p)>64*1024*1024)throw std::runtime_error("BREP size limit");
 TopoDS_Shape s;BRep_Builder b;if(!BRepTools::Read(s,p.string().c_str(),b)||s.IsNull())throw std::runtime_error("Invalid BREP serialization");return s;
}
static bool pureSolidTree(const TopoDS_Shape& s,int depth=0){
 if(depth>64)return false;
 if(s.ShapeType()==TopAbs_SOLID)return true;
 if(s.ShapeType()!=TopAbs_COMPOUND&&s.ShapeType()!=TopAbs_COMPSOLID)return false;
 for(TopoDS_Iterator it(s);it.More();it.Next())if(!pureSolidTree(it.Value(),depth+1))return false;
 return true;
}
static J properties(const TopoDS_Shape& s) {
 if(s.IsNull())return {{"status","INVALID"},{"error","Null shape"}};
 TopTools_IndexedMapOfShape faces,solids,shells,edges,vertices;
 TopExp::MapShapes(s,TopAbs_FACE,faces);TopExp::MapShapes(s,TopAbs_SOLID,solids);TopExp::MapShapes(s,TopAbs_SHELL,shells);TopExp::MapShapes(s,TopAbs_EDGE,edges);TopExp::MapShapes(s,TopAbs_VERTEX,vertices);
 BRepCheck_Analyzer analyzer(s,Standard_True);GProp_GProps v,a;BRepGProp::VolumeProperties(s,v);BRepGProp::SurfaceProperties(s,a);
 Bnd_Box box;BRepBndLib::AddOptimal(s,box,Standard_False,Standard_False);double x,y,z,X,Y,Z;box.Get(x,y,z,X,Y,Z);
 bool closed=true;for(int i=1;i<=shells.Extent();++i)closed=closed&&BRep_Tool::IsClosed(shells(i));
 double tol=0;for(int i=1;i<=vertices.Extent();++i)tol=std::max(tol,BRep_Tool::Tolerance(TopoDS::Vertex(vertices(i))));
 for(int i=1;i<=edges.Extent();++i)tol=std::max(tol,BRep_Tool::Tolerance(TopoDS::Edge(edges(i))));
 J invalid=J::array();for(TopExp_Explorer e(s,TopAbs_FACE);e.More();e.Next())if(!analyzer.IsValid(e.Current()))invalid.push_back("Invalid face");
 TopTools_IndexedDataMapOfShapeListOfShape incidence;TopExp::MapShapesAndAncestors(s,TopAbs_EDGE,TopAbs_FACE,incidence);bool manifold=true;for(int i=1;i<=incidence.Extent();++i)if(incidence.FindFromIndex(i).Extent()>2)manifold=false;
 bool pure=pureSolidTree(s);if(solids.Extent()==1){TopTools_IndexedMapOfShape solidFaces;TopExp::MapShapes(solids(1),TopAbs_FACE,solidFaces);pure=pure&&solidFaces.Extent()==faces.Extent();}
 auto centerCheck=v.CentreOfMass();bool finite=std::isfinite(v.Mass())&&std::isfinite(a.Mass())&&std::isfinite(x)&&std::isfinite(y)&&std::isfinite(z)&&std::isfinite(X)&&std::isfinite(Y)&&std::isfinite(Z)&&std::isfinite(centerCheck.X())&&std::isfinite(centerCheck.Y())&&std::isfinite(centerCheck.Z());
 std::string status=!analyzer.IsValid()||!closed||!manifold||!finite||v.Mass()<=0?"INVALID":solids.Extent()!=1||!pure?"UNSUPPORTED":"VALID";
 J fd=J::array();for(int i=1;i<=faces.Extent();++i){GProp_GProps f;BRepGProp::SurfaceProperties(faces(i),f);auto c=f.CentreOfMass();Bnd_Box fb;BRepBndLib::AddOptimal(faces(i),fb,Standard_False,Standard_False);double fx,fy,fz,fX,fY,fZ;fb.Get(fx,fy,fz,fX,fY,fZ);auto inertia=f.MatrixOfInertia();J moments=J::array();for(int r=1;r<=3;++r)for(int col=1;col<=3;++col)moments.push_back(inertia.Value(r,col));J record={{"slot",i},{"orientation",int(faces(i).Orientation())},{"area",f.Mass()},{"center",{c.X(),c.Y(),c.Z()}},{"bounds",{fx,fy,fz,fX,fY,fZ}},{"inertia",moments}};BRepAdaptor_Surface surface(TopoDS::Face(faces(i)));if(surface.GetType()==GeomAbs_Plane){double u0,u1,v0,v1;BRepTools::UVBounds(TopoDS::Face(faces(i)),u0,u1,v0,v1);gp_Pnt point;gp_Vec du,dv;surface.D1((u0+u1)/2,(v0+v1)/2,point,du,dv);auto normal=du.Crossed(dv);normal.Normalize();if(faces(i).Orientation()==TopAbs_REVERSED)normal.Reverse();record["plane_outward_normal"]={normal.X(),normal.Y(),normal.Z()};}fd.push_back(record);tol=std::max(tol,BRep_Tool::Tolerance(TopoDS::Face(faces(i))));}
 if(!closed)invalid.push_back("Closed shells are required for solid CAE");if(!manifold)invalid.push_back("Nonmanifold edge/face incidence");if(v.Mass()<=0)invalid.push_back("Nonpositive signed physical volume; check orientation or degenerate geometry");if(solids.Extent()!=1||!pure)invalid.push_back("Exactly one solid without auxiliary topology is supported");if(!finite)invalid.push_back("Non-finite geometric mass properties");if(!std::isfinite(tol)||tol<0){status="INVALID";invalid.push_back("Invalid shape tolerance");}
 auto c=v.CentreOfMass();return {{"status",status},{"shape_type",int(s.ShapeType())},{"analyzer_valid",analyzer.IsValid()},{"closed_shells",closed},{"manifold_edge_incidence",manifold},{"solid_count",solids.Extent()},{"shell_count",shells.Extent()},{"face_count",faces.Extent()},{"edge_count",edges.Extent()},{"vertex_count",vertices.Extent()},{"volume",v.Mass()},{"area",a.Mass()},{"centroid",{c.X(),c.Y(),c.Z()}},{"bounds",{x,y,z,X,Y,Z}},{"maximum_tolerance_m",tol},{"faces",fd},{"diagnostics",invalid},{"self_intersection_guarantee",false}};
}
template<class Op> static TopoDS_Shape booleanOp(const TopoDS_Shape& a,const TopoDS_Shape& b,J& history) {
 Op op(a,b);op.SetRunParallel(false);op.Build();if(!op.IsDone()||op.HasErrors())throw std::runtime_error("Boolean kernel failure");op.SimplifyResult(true,true);
 TopTools_IndexedMapOfShape out;TopExp::MapShapes(op.Shape(),TopAbs_FACE,out);
 int operand=0;for(auto input:{a,b}) {TopTools_IndexedMapOfShape src;TopExp::MapShapes(input,TopAbs_FACE,src);
 for(int i=1;i<=src.Extent();++i){J m=J::array(),g=J::array(),u=J::array();int unchanged=out.FindIndex(src(i));if(unchanged && out(unchanged).Orientation()==src(i).Orientation())u.push_back(unchanged);
 for(TopTools_ListIteratorOfListOfShape it(op.Modified(src(i)));it.More();it.Next()){int id=out.FindIndex(it.Value());if(id)m.push_back(id);}
 for(TopTools_ListIteratorOfListOfShape it(op.Generated(src(i)));it.More();it.Next()){int id=out.FindIndex(it.Value());if(id)g.push_back(id);}
 history.push_back({{"operand",operand},{"input_slot",i},{"unchanged",u},{"modified",m},{"generated",g},{"deleted",op.IsDeleted(src(i))}});
 }++operand;}return op.Shape();
}
static J classifyPair(const TopoDS_Shape& a,const TopoDS_Shape& b) {
 auto pa=properties(a),pb=properties(b);
 J r={{"classification","INCONCLUSIVE"},{"input_validation",{pa,pb}},{"common_volume_m3",nullptr},{"minimum_distance_m",nullptr},{"algorithm","occt-solid-pair-v1"}};
 if(pa["status"]!="VALID"||pb["status"]!="VALID"){r["classification"]="INVALID";r["diagnostic"]="Both inputs must be valid closed single solids";return r;}
 double scale=0,gap2=0;
 for(int i=0;i<3;++i){double alo=pa["bounds"][i],ahi=pa["bounds"][i+3],blo=pb["bounds"][i],bhi=pb["bounds"][i+3];scale=std::max(scale,std::max(ahi-alo,bhi-blo));double gap=std::max(0.0,std::max(alo-bhi,blo-ahi));gap2+=gap*gap;}
 double lt=std::max({1e-9,scale*1e-10,4*pa["maximum_tolerance_m"].get<double>(),4*pb["maximum_tolerance_m"].get<double>()});
 double vt=std::max(1e-18,scale*scale*scale*1e-12);
 r["linear_tolerance_m"]=lt;r["volume_tolerance_m3"]=vt;r["bounds_distance_lower_m"]=std::sqrt(gap2);
 if(std::sqrt(gap2)>lt){r["classification"]="SEPARATED";r["diagnostic"]="Validated native bounds safely disjoint";return r;}
 BRepAlgoAPI_Common op;op.SetArguments(TopTools_ListOfShape());
 TopTools_ListOfShape arguments,tools;arguments.Append(a);tools.Append(b);op.SetArguments(arguments);op.SetTools(tools);op.SetRunParallel(false);op.Build();
 if(!op.IsDone()||op.HasErrors()||op.HasWarnings()){r["diagnostic"]="Boolean common failed or emitted warnings";return r;}
 auto common=op.Shape();
 if(common.IsNull()||!BRepCheck_Analyzer(common,Standard_True).IsValid()){r["diagnostic"]="Null/invalid Boolean common result";return r;}
 double volume=0;int count=0;
 for(TopExp_Explorer it(common,TopAbs_SOLID);it.More();it.Next()){auto p=properties(it.Current());if(p["status"]!="VALID"){r["diagnostic"]="Invalid common solid";return r;}volume+=p["volume"].get<double>();++count;}
 r["common_valid"]=true;r["common_solid_count"]=count;r["common_volume_m3"]=volume;
 if(!std::isfinite(volume)||volume<0){r["diagnostic"]="Invalid common volume";return r;}
 if(volume>vt){r["classification"]="OVERLAPPING";r["diagnostic"]="Significant positive common solid volume";return r;}
 if(volume>0){r["diagnostic"]="Positive common volume below resolution threshold";return r;}
 BRepExtrema_DistShapeShape distance(a,b);distance.Perform();
 if(!distance.IsDone()||!std::isfinite(distance.Value())||distance.Value()<0){r["diagnostic"]="Native minimum distance failed";return r;}
 r["minimum_distance_m"]=distance.Value();r["classification"]=distance.Value()<=lt?"TOUCHING":"SEPARATED";r["diagnostic"]="Valid zero-volume common and native minimum distance";return r;
}
int main(int argc,char**argv){J response;int code=0;try {
 if(argc!=2)throw std::runtime_error("Expected request filename");auto path=local(argv[1]);if(fs::file_size(path)>1024*1024)throw std::runtime_error("Request limit");
 std::ifstream in(path);J q;in>>q;if(q.at("schema")!=1||q.at("units")!="m")throw std::runtime_error("Unsupported schema or units");
 std::string action=q.at("action");bool isPair=action=="classify_pair";bool isBoolean=action=="fuse"||action=="cut"||action=="common"||isPair;
 if(!isBoolean&&action!="validate"&&action!="step"&&action!="box"&&action!="cylinder"&&action!="sphere"&&action!="transform")throw std::runtime_error("Unknown action");
 if(!q.at("operation_id").is_string()||q.at("operation_id").get<std::string>().empty()||q.at("operation_id").get<std::string>().size()>100||!q.at("feature_id").is_string()||q.at("feature_id").get<std::string>().size()>1024||!q.at("input_hashes").is_array()||q.at("input_hashes").size()!=(isBoolean?2:1))throw std::runtime_error("Invalid request identity fields");
 if(sha256(local(q.at("input")))!=q.at("input_hashes")[0].get<std::string>())throw std::runtime_error("Native input SHA-256 mismatch");
 if(isBoolean&&sha256(local(q.at("tool")))!=q.at("input_hashes")[1].get<std::string>())throw std::runtime_error("Native tool SHA-256 mismatch");
 TopoDS_Shape s;
 if(action=="box"){auto d=q.at("dimensions");s=BRepPrimAPI_MakeBox(gp_Pnt(-d[0].get<double>()/2,-d[1].get<double>()/2,-d[2].get<double>()/2),d[0],d[1],d[2]).Shape();}
 else if(action=="cylinder"){auto d=q.at("dimensions");s=BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(0,-d[1].get<double>()/2,0),gp_Dir(0,1,0)),d[0].get<double>()/2,d[1]).Shape();}
 else if(action=="sphere")s=BRepPrimAPI_MakeSphere(q.at("dimensions")[0].get<double>()/2).Shape();
 else if(action=="step"){auto p=local(q.at("input"));STEPControl_Reader reader;if(reader.ReadFile(p.string().c_str())!=IFSelect_RetDone)throw std::runtime_error("STEP read failed");reader.SetSystemLengthUnit(1000.0);if(reader.TransferRoots()!=1)throw std::runtime_error("STEP assemblies/shells unsupported: exactly one root required");s=reader.OneShape();}
 else s=read(q.at("input"));
 auto before=properties(s);response={{"schema",1},{"units","m"},{"worker_version","1"},{"occt_version",OCC_VERSION_COMPLETE},{"operation_id",q.at("operation_id")},{"feature_id",q.at("feature_id")},{"input_hashes",q.at("input_hashes")},{"before",before}};
 J history=J::array();
 if(isPair){response["pair"]=classifyPair(s,read(q.at("tool")));response["ok"]=true;}
 else {
 if(action!="validate"&&before["status"]!="VALID")throw std::runtime_error("Invalid/unsupported input solid");
 if(action=="fuse"||action=="cut"||action=="common") {auto b=read(q.at("tool"));response["tool_before"]=properties(b);if(response["tool_before"]["status"]!="VALID")throw std::runtime_error("Invalid Boolean tool");
 if(action=="fuse")s=booleanOp<BRepAlgoAPI_Fuse>(s,b,history);if(action=="cut")s=booleanOp<BRepAlgoAPI_Cut>(s,b,history);if(action=="common")s=booleanOp<BRepAlgoAPI_Common>(s,b,history);
 } else if(action=="transform") {auto m=q.at("matrix");if(m.size()!=12)throw std::runtime_error("Expected affine 3x4 matrix");gp_GTrsf g;for(int i=1;i<=3;++i)for(int j=1;j<=4;++j)g.SetValue(i,j,m[(i-1)*4+j-1].get<double>());
 double norm[3]={0,0,0};for(int j=1;j<=3;++j)for(int i=1;i<=3;++i)norm[j-1]+=g.Value(i,j)*g.Value(i,j);
 bool similarity=true;for(int j=0;j<3;++j){similarity=similarity&&std::abs(norm[j]-norm[0])<=1e-12*std::max(1.0,norm[0]);for(int k=j+1;k<3;++k){double dot=0;for(int i=1;i<=3;++i)dot+=g.Value(i,j+1)*g.Value(i,k+1);similarity=similarity&&std::abs(dot)<=1e-12*std::max(1.0,norm[0]);}}
 if(similarity){gp_Trsf t;t.SetValues(g.Value(1,1),g.Value(1,2),g.Value(1,3),g.Value(1,4),g.Value(2,1),g.Value(2,2),g.Value(2,3),g.Value(2,4),g.Value(3,1),g.Value(3,2),g.Value(3,3),g.Value(3,4));BRepBuilderAPI_Transform tr(s,t,true);if(!tr.IsDone())throw std::runtime_error("Transform failed");s=tr.Shape();response["transform_api"]="BRepBuilderAPI_Transform";}
 else {BRepBuilderAPI_GTransform tr(s,g,true);if(!tr.IsDone())throw std::runtime_error("Transform failed");s=tr.Shape();response["transform_api"]="BRepBuilderAPI_GTransform";}
 } else if(action!="validate"&&action!="box"&&action!="cylinder"&&action!="sphere"&&action!="step")throw std::runtime_error("Unknown action");
 response["validation"]=properties(s);response["face_history"]=history;response["ok"]=true;
 if(response["validation"]["status"]=="VALID"&&action!="validate"){if(!BRepTools::Write(s,"output.brep.tmp"))throw std::runtime_error("BRep serialization write failed");response["output_sha256"]=sha256("output.brep.tmp");fs::rename("output.brep.tmp","output.brep");}
 }
 }catch(const Standard_Failure&e){response["ok"]=false;response["status"]="KERNEL_ERROR";response["error"]=e.GetMessageString();code=1;}
 catch(const std::exception&e){response["ok"]=false;std::string error=e.what();response["status"]=error.find("Unsupported")!=std::string::npos||error.find("Unknown")!=std::string::npos?"UNSUPPORTED":"INVALID";response["error"]=error;code=1;}
 response["schema"]=1;response["worker_version"]="1";response["occt_version"]=OCC_VERSION_COMPLETE;response["units"]="m";
 try{auto encoded=response.dump();if(encoded.size()>16*1024*1024){encoded=J({{"schema",1},{"ok",false},{"status","INCONCLUSIVE"},{"error","Native response exceeds 16 MiB"}}).dump();code=2;}std::ofstream out("response.json.tmp");out<<encoded;out.close();if(!out)throw std::runtime_error("Response write failed");fs::rename("response.json.tmp","response.json");}
 catch(const std::exception&e){std::cerr<<"Atomic native response publication failed: "<<e.what()<<std::endl;return 2;}return code;
}
