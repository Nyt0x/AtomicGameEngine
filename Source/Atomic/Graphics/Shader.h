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

#include "../Container/ArrayPtr.h"
#include "../Resource/Resource.h"

namespace Atomic
{

class ShaderVariation;

/// %Shader resource consisting of several shader variations.
class ATOMIC_API Shader : public Resource
{
    ATOMIC_OBJECT(Shader, Resource);

public:
    /// Construct.
    Shader(Context* context);
    /// Destruct.
    virtual ~Shader();
    /// Register object factory.
    static void RegisterObject(Context* context);

    /// Load resource from stream. May be called from a worker thread. Return true if successful.
    virtual bool BeginLoad(Deserializer& source);
    /// Finish resource loading. Always called from the main thread. Return true if successful.
    virtual bool EndLoad();

    /// Return a variation with defines. Separate multiple defines with spaces.
    ShaderVariation* GetVariation(ShaderType type, const String& defines);
    /// Return a variation with defines. Separate multiple defines with spaces.
    ShaderVariation* GetVariation(ShaderType type, const char* defines);

    /// Return shader source code based on type.
    const String& GetSourceCode(ShaderType type) const 
    { 
        switch (type)
        {
        case ShaderType::VS:
            return vsSourceCode_;
        	break;
        case ShaderType::PS:
            return psSourceCode_;
            break;
#ifdef DESKTOP_GRAPHICS
        case ShaderType::GS:
            return gsSourceCode_;
            break;
        case ShaderType::HS:
            return hsSourceCode_;
            break;
        case ShaderType::DS:
            return dsSourceCode_;
            break;
        case ShaderType::CS:
            return csSourceCode_;
            break;
#endif
        // [4/19/2017 adasilva] TODO
        //default:
        //    break;
        }
    }

    /// Return the latest timestamp of the shader code and its includes.
    unsigned GetTimeStamp() const { return timeStamp_; }

private:
    /// Process source code and include files. Return true if successful.
    bool ProcessSource(String& code, Deserializer& file);
    /// Sort the defines and strip extra spaces to prevent creation of unnecessary duplicate shader variations.
    String NormalizeDefines(const String& defines);
    /// Recalculate the memory used by the shader.
    void RefreshMemoryUse();

    /// Return a variation map from type
    HashMap<StringHash, SharedPtr<ShaderVariation> >& GetVariationMapFromType(ShaderType type)
    {
        switch (type)
        {
        case ShaderType::VS:
            return vsVariations_;
            break;
        case ShaderType::PS:
            return psVariations_;
            break;
#ifdef DESKTOP_GRAPHICS
        case ShaderType::GS:
            return gsVariations_;
            break;
        case ShaderType::HS:
            return hsVariations_;
            break;
        case ShaderType::DS:
            return dsVariations_;
            break;
        case ShaderType::CS:
            return csVariations_;
            break;
#endif
        // [4/19/2017 adasilva] TODO
        //default:
        //    break;
        }
    }

    /// Source code adapted for vertex shader.
    String vsSourceCode_;
    /// Source code adapted for pixel shader.
    String psSourceCode_;
    /// Source code adapted for geometry shader.
    String gsSourceCode_;
    /// Source code adapted for hull shader.
    String hsSourceCode_;
    /// Source code adapted for domain shader.
    String dsSourceCode_;
    /// Source code adapted for compute shader.
    String csSourceCode_;

    /// Vertex shader variations.
    HashMap<StringHash, SharedPtr<ShaderVariation> > vsVariations_;
    /// Pixel shader variations.
    HashMap<StringHash, SharedPtr<ShaderVariation> > psVariations_;
    /// Geometry shader variations.
    HashMap<StringHash, SharedPtr<ShaderVariation> > gsVariations_;
    /// Hull shader variations.
    HashMap<StringHash, SharedPtr<ShaderVariation> > hsVariations_;
    /// Domain shader variations.
    HashMap<StringHash, SharedPtr<ShaderVariation> > dsVariations_;
    /// Compute shader variations.
    HashMap<StringHash, SharedPtr<ShaderVariation> > csVariations_;
    /// Source code timestamp.
    unsigned timeStamp_;
    /// Number of unique variations so far.
    unsigned numVariations_;
};

}
