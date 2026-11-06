# NOTE: This makefile was generated with assistance from ChatGPT.
# Makefile for a CUDA + Assimp + SDL3 + GLEW + GLM project (Linux/WSL and Windows)

TARGET_NAME := assignment
SRC         := assignment.cu
NVCCFLAGS   := -std=c++17 -O2 -arch=native -diag-suppress=20012 -diag-suppress=20013

ifeq ($(OS),Windows_NT)
# ---------- Windows (nvcc + MSVC + vcpkg) ----------
# Run make from an "x64 Native Tools Command Prompt for VS" so cl.exe is on PATH.
VCPKG       ?= C:/vcpkg
VCPKG_ROOT  := $(VCPKG)/installed/x64-windows
# Check $(VCPKG_ROOT)/lib for the exact name; it may be assimp-vc142-mt etc.
ASSIMP_NAME ?= assimp-vc143-mt

TARGET      := $(TARGET_NAME).exe
INC         := -I"$(VCPKG_ROOT)/include"
LIBS        := -L"$(VCPKG_ROOT)/lib" -l$(ASSIMP_NAME) -lSDL3 -lglew32 -lopengl32
DLLS        := $(ASSIMP_NAME).dll SDL3.dll glew32.dll

all: $(TARGET)

$(TARGET): $(SRC)
	nvcc $(NVCCFLAGS) $(INC) $(SRC) -o $@ $(LIBS)
	$(foreach d,$(DLLS),cp "$(VCPKG_ROOT)/bin/$(d)" . 2>/dev/null;)

clean:
	-rm -f $(TARGET_NAME).exe $(TARGET_NAME).exp $(TARGET_NAME).lib $(DLLS) 2>/dev/null

else
# ---------- Linux / WSL (apt: libassimp-dev libglew-dev libglm-dev, SDL3 from apt or source) ----------
TARGET      := $(TARGET_NAME).out
INC         := $(shell pkg-config --cflags sdl3 glew 2>/dev/null)
LIBS        := -lassimp $(shell pkg-config --libs sdl3 glew 2>/dev/null) -lGL

all: $(TARGET)

$(TARGET): $(SRC)
	nvcc $(NVCCFLAGS) $(INC) $(SRC) -o $@ $(LIBS)

clean:
	rm -f $(TARGET)

endif

.PHONY: all clean