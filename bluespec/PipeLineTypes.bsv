import FloatingPoint::*;
import FixedPoint::*;

typedef 4 M_BITS;
typedef 10 T_BITS;
typedef 14 N_BITS;

typedef 1024 NUM_PIXELS;

typedef UInt#(N_BITS) Offset;
typedef UInt#(M_BITS) Intensity;
typedef UInt#(T_BITS) PixCoord;

typedef FixedPoint#(8, 8) Fractional;

typedef struct {
    Fractional x;
    Fractional y;
    Fractional z;
} Vec3 deriving(Bits);

typedef struct {
    Fractional xx;
    Fractional xy;
    Fractional xz;
    Fractional yx;
    Fractional yy;
    Fractional yz;
    Fractional zx;
    Fractional zy;
    Fractional zz;
} Mat3 deriving(Bits);

typedef struct {
    Mat3 m;
    Vec3 pos;
} Transform deriving(Bits);

typedef struct {
    PixCoord x;
    PixCoord y;
    Fractional  z;
} FragPos deriving(Bits);

typedef struct {
    FragPos pos;
    Intensity intensity;
} Frag deriving(Bits);

typedef struct {
    Vec3 a;
    Vec3 b;
    Vec3 c;
    Bool valid;
} Triangle deriving(Bits);

typedef struct {
    FragPos a;
    FragPos b;
    Bool valid;
} Line deriving(Bits);