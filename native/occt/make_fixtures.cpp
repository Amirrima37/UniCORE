#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <BRepTools.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <vector>
#include <TopExp_Explorer.hxx>
#include <STEPControl_Writer.hxx>
int main(){
 auto box=BRepPrimAPI_MakeBox(.1,.2,.1).Shape();
 if(!BRepTools::Write(box.Reversed(),"inverted.brep"))return 1;
 BRep_Builder builder;
 std::vector<TopoDS_Shape> ordered;for(TopExp_Explorer f(box,TopAbs_FACE);f.More();f.Next())ordered.push_back(f.Current());
 TopoDS_Shell reordered;builder.MakeShell(reordered);for(auto it=ordered.rbegin();it!=ordered.rend();++it)builder.Add(reordered,*it);reordered.Closed(true);
 TopoDS_Solid solid;builder.MakeSolid(solid);builder.Add(solid,reordered);
 if(!BRepTools::Write(box,"ordered.brep")||!BRepTools::Write(solid,"reordered.brep"))return 5;
 TopoDS_Shell shell;builder.MakeShell(shell);int i=0;
 for(TopExp_Explorer faces(box,TopAbs_FACE);faces.More();faces.Next())if(i++!=0)builder.Add(shell,faces.Current());
 if(!BRepTools::Write(shell,"open-shell.brep"))return 2;
 STEPControl_Writer writer;if(writer.Transfer(shell,STEPControl_AsIs)!=IFSelect_RetDone)return 3;
 return writer.Write("open-shell.step")==IFSelect_RetDone?0:4;
}
