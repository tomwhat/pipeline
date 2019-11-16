import FixedPoint::*;
import FIFO::*;
import Types::*;
import ClientServer::*;
import GetPut::*;

typedef Server#(
    Vec3,
    Vec3
) TransformAndDivide;

interface SettableTransformAndDivide;
    interface Put#(Transform) setTranform;
    interface TransformAndDivide;
endinterface

module mkTransformDivide(SettableTransformAndDivide);
    Reg#(Transform) transform <- mkRegU;

    interface setTransform = toPut(asReg(transform));
endmodule