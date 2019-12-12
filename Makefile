CONNECTALDIR ?= /mit/6.375/lab2019f/connectal
S2H_INTERFACES = \
	TransformReq:PipeLine.setTransform \
	TriangleReq:PipeLine.inputTriangles \
	StopReq:PipeLine.stopRunning \
	KillReq:PipeLine.killProgram
H2S_INTERFACES= \
	PipeLine:PipeLineIndication
BSVFILES += \
	bluespec/IfcPipeLine.bsv
BSVPATH += / \
	bluespec/ \
	$(CONNECTALDIR)/bsv
CPPFILES += \
	test.cpp \
	peachyPipeline.cpp \
	peachyPerspective.cpp \
	peachyLines.cpp \
	peachyMath.cpp \
	libraries/libbmp.cpp \

CONNECTALFLAGS += --mainclockperiod=20

CONNECTALFLAGS += --nonstrict

CONNECTALFLAGS += -Ilibraries

CONNECTALFLAGS += --cxxflags="-std=gnu++14"

include $(CONNECTALDIR)/Makefile.connectal

buildstuff:
	$(MAKE) build.verilator
	
hardware:
	$(MAKE) -j8 build.vc707g2

swmain: swtest.cpp peachyPipeline.cpp peachyPerspective.cpp peachyLines.cpp peachyMath.cpp peachyTypes.h
	g++ -std=gnu++14 -o swmain swtest.cpp peachyPipeline.cpp peachyPerspective.cpp peachyLines.cpp peachyMath.cpp libraries/libbmp.cpp -Ilibraries
