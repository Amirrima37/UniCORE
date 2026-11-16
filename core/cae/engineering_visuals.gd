extends RefCounted
static func number(value: float, precision := 3) -> String:
	if not is_finite(value): return "invalid"
	if value==0: return "0"
	var exponent:=int(floor(log(absf(value))/log(10.0)))
	if exponent < -3 or exponent >= 5:
		return (("%."+str(precision)+"f") % (value/pow(10,exponent)))+" × 10^"+str(exponent)
	return ("%."+str(precision)+"f") % value
static func color(value: float, low: float, high: float, palette := "viridis", bands := 0) -> Color:
	if not is_finite(value): return Color.MAGENTA
	var t:=clampf((value-low)/(high-low),0,1) if high-low>maxf(absf(low),absf(high))*1e-6 else 0.5
	if bands>1: t=round(t*(bands-1))/(bands-1)
	var stops: Array=[Color("440154"),Color("3b528b"),Color("21918c"),Color("5ec962"),Color("fde725")]
	match palette:
		"diverging": stops=[Color("2166ac"),Color("f7f7f7"),Color("b2182b")]
		"temperature": stops=[Color("1a1042"),Color("7b2c83"),Color("d44a39"),Color("fca636"),Color("fcfdbf")]
		"cividis": stops=[Color("00224e"),Color("434e6c"),Color("7d7c78"),Color("bcae6c"),Color("fee838")]
	var x:=t*(stops.size()-1);var i:=mini(int(x),stops.size()-2)
	return stops[i].lerp(stops[i+1],x-i)
