CONNECTALDIR ?= connectal
S2H_INTERFACES = \
	TransformReq:PipeLine.setTransform \
	TriangleReq:PipeLine.inputTriangles
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
	peachyTypes.h \
	libraries/libbmp.h \

CONNECTALFLAGS += --mainclockperiod=20
# CONNECTALFLAGS += --cxxflags="peachyPipeline.cpp peachyPerspective.cpp peachyLines.cpp peachyMath.cpp peachyTypes.h -std=gnu++11 -Ilibbmp/CPP "
# CONNECTALFLAGS += --cxxflags="-std=gnu++11"

CONNECTALFLAGS += --nonstrict
CONNECTALFLAGS += -I libraries
#include $(CONNECTALDIR)/Makefile.connectal


swmain: test.cpp peachyPipeline.cpp peachyPerspective.cpp peachyLines.cpp peachyMath.cpp peachyTypes.h
	g++ -o swmain test.cpp peachyPipeline.cpp peachyPerspective.cpp peachyLines.cpp peachyMath.cpp libraries/libbmp.cpp -Ilibraries
