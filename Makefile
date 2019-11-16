
main: test.cpp peachyPipeline.cpp peachyPerspective.cpp peachyLines.cpp peachyMath.cpp peachyTypes.h
	g++ -o main test.cpp peachyPipeline.cpp peachyPerspective.cpp peachyLines.cpp peachyMath.cpp libbmp/CPP/libbmp.cpp -Ilibbmp/CPP
