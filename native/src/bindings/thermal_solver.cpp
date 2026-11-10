#include "thermal_solver.hpp"
#include "structural_solver.hpp"
#include "kernels/thermal_solver.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <set>
#include <godot_cpp/classes/ref.hpp>
using namespace godot;
namespace {
Array arr(Variant v){if(v.get_type()!=Variant::ARRAY)throw std::runtime_error("INVALID_ARRAY");return v;}
Dictionary dict(Variant v){if(v.get_type()!=Variant::DICTIONARY)throw std::runtime_error("INVALID_DICTIONARY");return v;}
double number(Variant v){if(v.get_type()!=Variant::INT&&v.get_type()!=Variant::FLOAT)throw std::runtime_error("MISSING_OR_INVALID_THERMAL_PROPERTY");double x=v.get_type()==Variant::INT?double(int64_t(v)):double(v);if(!std::isfinite(x))throw std::runtime_error("NONFINITE_INPUT");return x;}
Array xyz(unicore::structural::V v){Array a;for(double x:v)a.append(x);return a;}
}
void UniCoreThermalSolver::_bind_methods(){ClassDB::bind_method(D_METHOD("get_phase"),&UniCoreThermalSolver::get_phase);ClassDB::bind_method(D_METHOD("solve_model","project"),&UniCoreThermalSolver::solve_model);ClassDB::bind_method(D_METHOD("cancel"),&UniCoreThermalSolver::cancel);ClassDB::bind_method(D_METHOD("reset_cancel"),&UniCoreThermalSolver::reset_cancel);}
Dictionary UniCoreThermalSolver::solve_model(const Dictionary &project){
    phase.store(1);Dictionary result;
    try{
        Dictionary analysis=project.get("analysis",Dictionary());String type=analysis.get("type","steady_thermal");if(type!="steady_thermal"&&type!="transient_thermal")throw std::runtime_error("UNSUPPORTED_THERMAL_ANALYSIS");bool transient=type=="transient_thermal";
        Dictionary old=dict(project.get("mesh",Variant()));int divisions=int(number(old.get("divisions",0)));
        Ref<UniCoreStructuralSolver> mesher;mesher.instantiate();Dictionary generated=mesher->generate_mesh(project,divisions);if(!bool(generated.get("ok",false)))return generated;
        Dictionary mesh=generated["mesh"];Array nodes=mesh["nodes"],hexes=mesh["elements"],parts=arr(project["parts"]);Dictionary regions=mesh["regions"];
        unicore::thermal::Model model;for(int i=0;i<nodes.size();++i){auto v=arr(nodes[i]);model.nodes.push_back({number(v[0]),number(v[1]),number(v[2])});}model.fixed.assign(nodes.size(),false);model.temperature.assign(nodes.size(),0);
        const int split[6][4]={{0,1,2,6},{0,2,3,6},{0,3,7,6},{0,7,4,6},{0,4,5,6},{0,5,1,6}};
        const int face_nodes[6][4]={{0,3,7,4},{1,5,6,2},{0,4,5,1},{3,2,6,7},{0,1,2,3},{4,7,6,5}};
        int cells=divisions*divisions*divisions;Array elements;
        for(int pi=0;pi<parts.size();++pi){
            auto part=dict(parts[pi]),material=dict(part["material"]);double k=number(material.get("k",Variant())),capacity=0,source=number(part.get("heat_source",0));if(transient){double density=number(material.get("density",Variant())),cp=number(material.get("cp",Variant()));if(density<=0||cp<=0)throw std::runtime_error("POSITIVE_DENSITY_AND_HEAT_CAPACITY_REQUIRED");capacity=density*cp;}
            for(int h=pi*cells;h<(pi+1)*cells;++h){auto hex=arr(hexes[h]);for(auto &local:split){unicore::thermal::Element e;e.conductivity=k;e.capacity=capacity;e.source=source;Array ids;for(int j=0;j<4;++j){e.nodes[j]=int(hex[local[j]]);ids.append(e.nodes[j]);}model.elements.push_back(e);elements.append(ids);}}
            auto faces=dict(regions[part["id"]]);Array conditions=arr(part.get("thermal",Array()));bool anchored=transient;
            for(int bc_index=0;bc_index<conditions.size();++bc_index){auto bc=dict(conditions[bc_index]);String face=bc.get("face","");if(!faces.has(face))throw std::runtime_error("INVALID_THERMAL_FACE");Array ids=arr(faces[face]);String kind=bc.get("kind","");
                if(kind=="temperature"){anchored=true;double t=number(bc.get("value",Variant()));if(t<0)throw std::runtime_error("NEGATIVE_KELVIN");for(int i=0;i<ids.size();++i){int id=ids[i];if(model.fixed[id]&&std::abs(model.temperature[id]-t)>1e-10)throw std::runtime_error("CONFLICTING_TEMPERATURES");model.fixed[id]=true;model.temperature[id]=t;}continue;}
                if(kind!="flux"&&kind!="convection")throw std::runtime_error("UNSUPPORTED_THERMAL_BOUNDARY");
                double flux=kind=="flux"?number(bc.get("value",Variant())):0,h=kind=="convection"?number(bc.get("h",Variant())):0,ambient=kind=="convection"?number(bc.get("ambient",Variant())):0;if(h>0)anchored=true;
                std::set<int> group;for(int i=0;i<ids.size();++i)group.insert(int(ids[i]));
                for(int hi=pi*cells;hi<(pi+1)*cells;++hi){auto hex=arr(hexes[hi]);for(auto &f:face_nodes){bool boundary=true;for(int j:f)if(!group.count(int(hex[j])))boundary=false;if(!boundary)continue;for(int half=0;half<2;++half){unicore::thermal::Surface surface;surface.nodes={int(hex[f[0]]),int(hex[f[half+1]]),int(hex[f[half+2]])};surface.flux=flux;surface.h=h;surface.ambient=ambient;model.surfaces.push_back(surface);}}}
            }
            if(!anchored)throw std::runtime_error("EACH_THERMAL_BODY_REQUIRES_TEMPERATURE_OR_CONVECTION");
        }
        double dt=transient?number(analysis.get("time_step",Variant())):0;int steps=transient?int(number(analysis.get("steps",Variant()))):0;if(transient&&(steps<1||steps>200))throw std::runtime_error("THERMAL_STEPS_1_TO_200_REQUIRED");
        phase.store(4);auto solution=unicore::thermal::solve(model,cancelled,dt,steps,number(analysis.get("initial_temperature",293.15)),&phase);
        Array temperatures,flux,reactions,history,times;for(double t:solution.temperature)temperatures.append(t);for(double q:solution.reaction)reactions.append(q);for(auto q:solution.flux)flux.append(xyz(q));for(auto &step:solution.history){Array frame;for(double t:step)frame.append(t);history.append(frame);}for(double time:solution.times)times.append(time);
        phase.store(6);Array warnings;
        for(int i=0;i<parts.size();++i){auto part=dict(parts[i]),material=dict(part["material"]);Variant range=material.get("temperature_range_K",Variant());
            if(range.get_type()==Variant::ARRAY){auto bounds=arr(range);if(bounds.size()==2&&(number(bounds[0])>*std::min_element(solution.temperature.begin(),solution.temperature.end())||number(bounds[1])<*std::max_element(solution.temperature.begin(),solution.temperature.end())))warnings.append(String(part.get("name","Body"))+": CONSTANT_PROPERTIES_OUTSIDE_DOCUMENTED_TEMPERATURE_RANGE");}
            else warnings.append(String(part.get("name","Body"))+": MATERIAL_TEMPERATURE_RANGE_UNSPECIFIED");
        }
        result["warnings"]=warnings;result["ok"]=true;result["analysis_type"]=type;result["revision"]=project.get("revision",0);result["backend"]="C++ scalar TET4 conduction / CSR-PCG / lumped backward Euler when transient";
        result["nodes"]=nodes;result["elements"]=elements;result["tetrahedra"]=elements;result["temperature"]=temperatures;result["heat_flux"]=flux;result["heat_reactions"]=reactions;result["relative_residual"]=solution.residual;result["iterations"]=solution.iterations;result["energy_balance_W"]=solution.energy_balance;result["heat_input_W"]=solution.heat_input;result["convection_loss_W"]=solution.convection_loss;result["storage_rate_W"]=solution.storage_rate;result["history"]=history;result["times"]=times;result["mesh_divisions"]=divisions;result["mesh_quality"]=mesh["quality"];result["min_temperature"]=*std::min_element(solution.temperature.begin(),solution.temperature.end());result["max_temperature"]=*std::max_element(solution.temperature.begin(),solution.temperature.end());
    }catch(const std::exception &e){result["ok"]=false;result["error"]=e.what();}return result;
}
