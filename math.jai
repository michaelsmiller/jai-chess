Vector2 :: struct($T : Type) {
  x, y : T;
}
Vector3 :: struct($T : Type) {
  x, y, z : T;
}
Color :: Vector3(float);

Vector4 :: struct($T : Type) {
  x, y, z, w : T;
}
make_vector2 :: inline (x : $T, y : T) -> Vector2(T) {
  v : Vector2(T);
  v.x = x;
  v.y = y;
  return v;
}
make_vector3 :: inline (x : $T, y : T, z: T) -> Vector3(T) {
  v : Vector3(T);
  v.x = x;
  v.y = y;
  v.z = z;
  return v;
}

repeat :: ($n : int, code : Code) #expand {
  #assert n > 1;
  #if n == 2 {
    #insert code;
    #insert code;
  }
  else #if n == 3 {
    #insert code;
    #insert code;
    #insert code;
  }
  else #if n == 4 {
    #insert code;
    #insert code;
    #insert code;
    #insert code;
  }
  else #assert false;
}

operator + :: (a : Vector3($T), b : Vector3(T)) -> Vector3(T) {
  c : Vector3(T);
  c.x = a.x + b.x;
  c.y = a.y + b.y;
  c.z = a.z + b.z;
  return c;
}

// scalar multiplication and division:
// @note I don't think scalar division is ever a good idea, but if gets put in
//       then please make it check for 0

operator * :: (v : Vector3($T), a : $S) -> Vector3(T) #symmetric #modify {
  // Only allow this to polymorph for scalars
  if T.type == {
    case .INTEGER; return;
    case .FLOAT; return;
  }
  T = null;
}
{
  w : Vector3(T);
  w.x = v.x * cast(T) a;
  w.y = v.y * cast(T) a;
  w.z = v.z * cast(T) a;
  return w;
}

