//=============================================================================
//=============================================================================

#pragma once

//#include "../Atomic.h"
//#include "../Container/Vector.h"
#include "../Container/ArrayPtr.h"

using namespace Atomic;

//=============================================================================
//=============================================================================
class complex {
  private:
  protected:
  public:
    float a, b;
    static unsigned int additions, multiplications;
    complex();
    complex(float a, float b);
    complex conj();
    complex operator*(const complex& c) const;
    complex operator+(const complex& c) const;
    complex operator-(const complex& c) const;
    complex operator-() const;
    complex operator*(const float c) const;
    complex& operator=(const complex& c);
    static void reset();
};

class cFFT {
  private:
	unsigned int N, which;
	unsigned int log_2_N;
	float pi2;
	unsigned int *reversed;
	complex **T;
	complex *c[2];
  protected:
  public:
	cFFT(unsigned int N);
	~cFFT();
	unsigned int reverse(unsigned int i);
	complex t(unsigned int x, unsigned int N);
	void fft(complex* input, complex* output, int stride, int offset);
};

