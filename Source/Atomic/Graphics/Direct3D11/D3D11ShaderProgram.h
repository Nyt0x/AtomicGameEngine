//
// Copyright (c) 2008-2017 the Urho3D project.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#pragma once

#include "../../Container/HashMap.h"
#include "../../Graphics/ConstantBuffer.h"
#include "../../Graphics/Graphics.h"
#include "../../Graphics/ShaderVariation.h"

namespace Atomic
{

/// Combined information for specific vertex and pixel shaders.
class ATOMIC_API ShaderProgram : public RefCounted
{
    ATOMIC_REFCOUNTED(ShaderProgram)

public:
    /// Construct.
    ShaderProgram(Graphics* graphics
        , ShaderVariation* vertexShader
        , ShaderVariation* pixelShader
        , ShaderVariation* geometryShader
        , ShaderVariation* hullShader
        , ShaderVariation* domainShader
        , ShaderVariation* computeShader)
    {
        // Verify shader variation exist
        // Create needed constant buffers
        // Then copy parameters, add direct links to constant buffers
        
        if(vertexShader)
        {
            const unsigned* vsBufferSizes = vertexShader->GetConstantBufferSizes();
            for (unsigned i = 0; i < MAX_SHADER_PARAMETER_GROUPS; ++i)
            {
                if (vsBufferSizes[i])
                    vsConstantBuffers_[i] = graphics->GetOrCreateConstantBuffer(ShaderType::VS, i, vsBufferSizes[i]);
            }

            const HashMap<StringHash, ShaderParameter>& vsParams = vertexShader->GetParameters();
            for (HashMap<StringHash, ShaderParameter>::ConstIterator i = vsParams.Begin(); i != vsParams.End(); ++i)
            {
                parameters_[i->first_] = i->second_;
                parameters_[i->first_].bufferPtr_ = vsConstantBuffers_[i->second_.buffer_].Get();
            }
        }

        if(pixelShader)
        {
            const unsigned* psBufferSizes = pixelShader->GetConstantBufferSizes();
            for (unsigned i = 0; i < MAX_SHADER_PARAMETER_GROUPS; ++i)
            {
                if (psBufferSizes[i])
                    psConstantBuffers_[i] = graphics->GetOrCreateConstantBuffer(ShaderType::PS, i, psBufferSizes[i]);
            }

            const HashMap<StringHash, ShaderParameter>& psParams = pixelShader->GetParameters();
            for (HashMap<StringHash, ShaderParameter>::ConstIterator i = psParams.Begin(); i != psParams.End(); ++i)
            {
                parameters_[i->first_] = i->second_;
                parameters_[i->first_].bufferPtr_ = psConstantBuffers_[i->second_.buffer_].Get();
            }
        }

#ifdef DESKTOP_GRAPHICS
        if(geometryShader)
        {
            const unsigned* gsBufferSizes = geometryShader->GetConstantBufferSizes();
            for (unsigned i = 0; i < MAX_SHADER_PARAMETER_GROUPS; ++i)
            {
                if (gsBufferSizes[i])
                    gsConstantBuffers_[i] = graphics->GetOrCreateConstantBuffer(ShaderType::GS, i, gsBufferSizes[i]);
            }

            const HashMap<StringHash, ShaderParameter>& gsParams = geometryShader->GetParameters();
            for (HashMap<StringHash, ShaderParameter>::ConstIterator i = gsParams.Begin(); i != gsParams.End(); ++i)
            {
                parameters_[i->first_] = i->second_;
                parameters_[i->first_].bufferPtr_ = gsConstantBuffers_[i->second_.buffer_].Get();
            }
        }

        if(hullShader)
        {
            const unsigned* hsBufferSizes = hullShader->GetConstantBufferSizes();
            for (unsigned i = 0; i < MAX_SHADER_PARAMETER_GROUPS; ++i)
            {
                if (hsBufferSizes[i])
                    hsConstantBuffers_[i] = graphics->GetOrCreateConstantBuffer(ShaderType::HS, i, hsBufferSizes[i]);
            }

            const HashMap<StringHash, ShaderParameter>& hsParams = hullShader->GetParameters();
            for (HashMap<StringHash, ShaderParameter>::ConstIterator i = hsParams.Begin(); i != hsParams.End(); ++i)
            {
                parameters_[i->first_] = i->second_;
                parameters_[i->first_].bufferPtr_ = hsConstantBuffers_[i->second_.buffer_].Get();
            }
        }

        if(domainShader)
        {
            const unsigned* dsBufferSizes = domainShader->GetConstantBufferSizes();
            for (unsigned i = 0; i < MAX_SHADER_PARAMETER_GROUPS; ++i)
            {
                if (dsBufferSizes[i])
                    dsConstantBuffers_[i] = graphics->GetOrCreateConstantBuffer(ShaderType::DS, i, dsBufferSizes[i]);
            }

            const HashMap<StringHash, ShaderParameter>& dsParams = domainShader->GetParameters();
            for (HashMap<StringHash, ShaderParameter>::ConstIterator i = dsParams.Begin(); i != dsParams.End(); ++i)
            {
                parameters_[i->first_] = i->second_;
                parameters_[i->first_].bufferPtr_ = dsConstantBuffers_[i->second_.buffer_].Get();
            }
        }

        if(computeShader)
        {
            const unsigned* csBufferSizes = computeShader->GetConstantBufferSizes();
            for (unsigned i = 0; i < MAX_SHADER_PARAMETER_GROUPS; ++i)
            {
                if (csBufferSizes[i])
                    csConstantBuffers_[i] = graphics->GetOrCreateConstantBuffer(ShaderType::CS, i, csBufferSizes[i]);
            }

            const HashMap<StringHash, ShaderParameter>& csParams = computeShader->GetParameters();
            for (HashMap<StringHash, ShaderParameter>::ConstIterator i = csParams.Begin(); i != csParams.End(); ++i)
            {
                parameters_[i->first_] = i->second_;
                parameters_[i->first_].bufferPtr_ = csConstantBuffers_[i->second_.buffer_].Get();
            }
        }
#endif

        // Optimize shader parameter lookup by rehashing to next power of two
        parameters_.Rehash(NextPowerOfTwo(parameters_.Size()));

    }

    /// Destruct.
    ~ShaderProgram()
    {
    }

    /// Combined parameters from the vertex and pixel shader.
    HashMap<StringHash, ShaderParameter> parameters_;
    /// Vertex shader constant buffers.
    SharedPtr<ConstantBuffer> vsConstantBuffers_[MAX_SHADER_PARAMETER_GROUPS];
    /// Pixel shader constant buffers.
    SharedPtr<ConstantBuffer> psConstantBuffers_[MAX_SHADER_PARAMETER_GROUPS];
    /// Geometry shader constant buffers.
    SharedPtr<ConstantBuffer> gsConstantBuffers_[MAX_SHADER_PARAMETER_GROUPS];
    /// Hull shader constant buffers.
    SharedPtr<ConstantBuffer> hsConstantBuffers_[MAX_SHADER_PARAMETER_GROUPS];
    /// Domain shader constant buffers.
    SharedPtr<ConstantBuffer> dsConstantBuffers_[MAX_SHADER_PARAMETER_GROUPS];
    /// Compute shader constant buffers.
    SharedPtr<ConstantBuffer> csConstantBuffers_[MAX_SHADER_PARAMETER_GROUPS];
};

}
