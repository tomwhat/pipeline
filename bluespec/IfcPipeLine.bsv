// import PipeLineTypes::*;

// TB: I hardcoded the bit width for connectal, otherwise it confuses the parser

interface TransformReq;
    method Action set(
	Bit#(16) posx, Bit#(16) posy, Bit#(16) posz,
	Bit#(16) mxx , Bit#(16) mxy , Bit#(16) mxz ,
	Bit#(16) myx , Bit#(16) myy , Bit#(16) myz ,
	Bit#(16) mzx , Bit#(16) mzy , Bit#(16) mzz );
endinterface

interface TriangleReq;
    method Action enq(
	Bit#(16) ax, Bit#(16) ay, Bit#(16) az,
	Bit#(16) bx, Bit#(16) by, Bit#(16) bz,
	Bit#(16) cx, Bit#(16) cy, Bit#(16) cz,
	Bool valid);
endinterface

interface StopReq;
	method Action stop;
endinterface

// HW to Sw
interface PipeLineIndication;
    method Action callbackFrag(
	Bit#(10) fposx,
	Bit#(10) fposy,
	Bit#(16) fposz,
	Bit#(4) fintensity);
endinterface

// TB: There are limitations in Connectal for the width of the argument being sent. Recall to do a small session on connectal communication model.

// // This is the only interface I should need
// // for connectal in the end.
// // For development/testing, should I just add
// // get___() methods for each stage?
// interface PipeLine;
//     interface Put#(Transform) setTransform;
//     interface Put#(Triangle) pushTriangle;
//     interface Get#(Frag) getFrag;
// endinterface
// // Stretch goal: getFrameBuffer() instead
// // of getFrag() :)
