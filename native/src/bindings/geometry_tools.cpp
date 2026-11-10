#include "geometry_tools.hpp"
#include "kernels/geometry_metrics.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
using namespace godot;
namespace {
double numeric(Variant v) {
    if(v.get_type()!=Variant::INT&&v.get_type()!=Variant::FLOAT)throw std::runtime_error("INVALID_NUMBER");
    double x=v.get_type()==Variant::INT ? double(int64_t(v)) : double(v);
    if(!std::isfinite(x))throw std::runtime_error("INVALID_NUMBER");return x;
}
std::array<double,3> vector(Variant v) {
    if(v.get_type()!=Variant::ARRAY)throw std::runtime_error("INVALID_VECTOR");Array a=v;
    if(a.size()!=3)throw std::runtime_error("INVALID_VECTOR");return {numeric(a[0]),numeric(a[1]),numeric(a[2])};
}
}
void UniCoreGeometryTools::_bind_methods() {
    ClassDB::bind_method(D_METHOD("validate_material","material","analysis"),&UniCoreGeometryTools::validate_material);
    ClassDB::bind_method(D_METHOD("measure_primitive","part"),&UniCoreGeometryTools::measure_primitive);
}
Dictionary UniCoreGeometryTools::measure_primitive(const Dictionary &part) const {
    Dictionary result;
    try {
        String kind=part.get("kind","");
        using Kind=unicore::geometry::Kind;Kind shape;
        if(kind=="Box")shape=Kind::Box;else if(kind=="Sphere")shape=Kind::Sphere;else if(kind=="Cylinder")shape=Kind::Cylinder;else if(kind=="Pipe")shape=Kind::Pipe;else throw std::runtime_error("UNSUPPORTED_GEOMETRY");
        auto d=vector(part.get("dimensions",Variant()));
        std::array<double,3> scale{1,1,1};if(part.has("scale"))scale=vector(part["scale"]);
        for(double x:scale)if(x<=0)throw std::runtime_error("INVALID_SCALE");
        if(shape!=Kind::Box&&std::abs(scale[0]-scale[2])>1e-12)throw std::runtime_error("NONUNIFORM_RADIAL_SCALE_UNSUPPORTED");
        if(shape==Kind::Sphere&&std::abs(scale[0]-scale[1])>1e-12)throw std::runtime_error("NONUNIFORM_SPHERE_SCALE_UNSUPPORTED");
        for(int i=0;i<3;++i)d[i]*=scale[i];
        if(Variant(part.get("material",Variant())).get_type()!=Variant::DICTIONARY)throw std::runtime_error("INVALID_MATERIAL");
        Dictionary material=part["material"];
        auto metrics=unicore::geometry::measure(shape,d,part.has("inner_diameter")?numeric(part["inner_diameter"])*scale[0]:0,numeric(material.get("density",Variant())));
        result["ok"]=true;result["volume_m3"]=metrics.volume;result["area_m2"]=metrics.area;result["mass_kg"]=metrics.mass;
        Array inertia;for(double x:metrics.inertia)inertia.append(x);result["local_inertia_kg_m2"]=inertia;
        result["backend"]="C++ analytic primitive geometry";
    }catch(const std::exception &e){result["ok"]=false;result["error"]=e.what();}return result;
}
Dictionary UniCoreGeometryTools::validate_material(const Dictionary &material,const String &analysis) const {
    Dictionary result;Array errors,missing;
    String model=material.get("model","isotropic_linear_elastic");
    if(String(material.get("units","SI"))!="SI")errors.append("MATERIAL_UNITS_MUST_BE_SI");
    const char *positive[]={"E","density","G","K","yield_strength","ultimate_strength","k","cp","mu","kinematic_viscosity","compressibility","electrical_conductivity","electrical_resistivity","relative_permittivity","relative_permeability"};
    for(auto key:positive)if(material.has(key)&&Variant(material[key]).get_type()!=Variant::NIL){try{if(numeric(material[key])<=0)errors.append(String("NONPOSITIVE_")+key);}catch(...){errors.append(String("INVALID_")+key);}}
    for(auto key:{"nu","alpha","emissivity","damping_ratio"})if(material.has(key)&&Variant(material[key]).get_type()!=Variant::NIL){try{double v=numeric(material[key]);if(String(key)=="nu"&&(v<=-1||v>=.5))errors.append("INVALID_POISSON_RATIO");if((String(key)=="emissivity"||String(key)=="damping_ratio")&&(v<0||v>1))errors.append(String("INVALID_")+key);}catch(...){errors.append(String("INVALID_")+key);}}
    Array required;
    if(analysis=="static_structural") {required.append("E");required.append("nu");if(model!="isotropic_linear_elastic")errors.append("CONSTITUTIVE_MODEL_NOT_SUPPORTED_BY_STATIC_SOLVER");}
    else if(analysis=="steady_thermal")required.append("k");
    else if(analysis=="transient_thermal"){required.append("k");required.append("density");required.append("cp");}
    else if(analysis!="definition")errors.append("UNSUPPORTED_ANALYSIS");
    for(int i=0;i<required.size();++i)if(!material.has(required[i])||Variant(material[required[i]]).get_type()==Variant::NIL)missing.append(required[i]);
    Dictionary derived;
    if(model=="isotropic_linear_elastic"&&errors.is_empty()&&material.has("E")&&material.has("nu")&&Variant(material["E"]).get_type()!=Variant::NIL&&Variant(material["nu"]).get_type()!=Variant::NIL){
        double E=numeric(material["E"]),nu=numeric(material["nu"]);derived["G"]=E/(2*(1+nu));derived["K"]=E/(3*(1-2*nu));
        for(auto key:{"G","K"})if(material.has(key)&&Variant(material[key]).get_type()!=Variant::NIL&&std::abs(numeric(material[key])-double(derived[key]))>1e-6*double(derived[key]))errors.append(String("INCONSISTENT_ISOTROPIC_")+key);
    }
    result["derived_from_E_nu"]=derived;result["errors"]=errors;result["missing"]=missing;result["valid_definition"]=errors.is_empty();result["ok"]=errors.is_empty()&&missing.is_empty();return result;
}
