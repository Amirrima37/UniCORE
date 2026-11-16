extends RefCounted
## v2: sorted string keys, ordered arrays, exact binary64 numbers, normalized zero.
const VERSION = 2
static func canonical(value) -> String:
 if value is Dictionary:
  var keys=value.keys();keys.sort()
  var entries=PackedStringArray()
  for key in keys:entries.append(JSON.stringify(str(key))+":"+canonical(value[key]))
  return "{"+",".join(entries)+"}"
 if value is Array:
  var entries=PackedStringArray()
  for item in value:entries.append(canonical(item))
  return "["+",".join(entries)+"]"
 if value is int:return "i"+str(value)+";"
 if value is float:
  var number=float(value)
  if number==0.0:number=0.0
  # Integral floats and JSON integer conversions share an exact integer token.
  if is_finite(number) and number>=-9223372036854775808.0 and number<9223372036854775807.0 and number==floor(number):return "i"+str(int(number))+";"
  var bytes=PackedByteArray();bytes.resize(8);bytes.encode_double(0,number)
  return "f"+bytes.hex_encode()+";"
 return JSON.stringify(value)
static func fingerprint(mesh: Dictionary) -> String:
 return ("unicore-mesh-v2:"+canonical(mesh)).sha256_text()
static func legacy(mesh: Dictionary) -> String:
 return JSON.stringify(JSON.parse_string(JSON.stringify(mesh,"",true,true)),"",true,true).sha256_text()

