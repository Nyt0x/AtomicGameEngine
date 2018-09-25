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

#include "../Graphics/GraphicsDefs.h"
#include "../Resource/Resource.h"

namespace Atomic
{

class ShaderVariation;

/// Lighting mode of a pass.
enum PassLightingMode
{
    LIGHTING_UNLIT = 0,
    LIGHTING_PERVERTEX,
    LIGHTING_PERPIXEL
};

/// %Material rendering pass, which defines shaders and render state.
class ATOMIC_API Pass : public RefCounted
{
    ATOMIC_REFCOUNTED(Pass)

public:
    /// Construct.
    Pass(const String& passName);
    /// Destruct.
    ~Pass();

    /// Set blend mode.
    void SetBlendMode(BlendMode mode);
    /// Set culling mode override. By default culling mode is read from the material instead. Set the illegal culling mode MAX_CULLMODES to disable override again.
    void SetCullMode(CullMode mode);
    /// Set depth compare mode.
    void SetDepthTestMode(CompareMode mode);
    /// Set pass lighting mode, affects what shader variations will be attempted to be loaded.
    void SetLightingMode(PassLightingMode mode);
    /// Set depth write on/off.
    void SetDepthWrite(bool enable);
    /// Set alpha-to-coverage on/off.
    void SetAlphaToCoverage(bool enable);
    /// Set whether requires desktop level hardware.
    void SetIsDesktop(bool enable);
    /// Set vertex shader name.
    void SetVertexShader(const String& name);
    /// Set pixel shader name.
    void SetPixelShader(const String& name);
    /// Set geometry shader name.
    void SetGeometryShader(const String& name);
    /// Set hull shader name.
    void SetHullShader(const String& name);
    /// Set domain shader name.
    void SetDomainShader(const String& name);
    /// Set compute shader name.
    void SetComputeShader(const String& name);
    /// Set vertex shader defines. Separate multiple defines with spaces.
    void SetVertexShaderDefines(const String& defines);
    /// Set pixel shader defines. Separate multiple defines with spaces.
    void SetPixelShaderDefines(const String& defines);
    /// Set geometry shader defines. Separate multiple defines with spaces.
    void SetGeometryShaderDefines(const String& defines);
    /// Set hull shader defines. Separate multiple defines with spaces.
    void SetHullShaderDefines(const String& defines);
    /// Set domain shader defines. Separate multiple defines with spaces.
    void SetDomainShaderDefines(const String& defines);
    /// Set compute shader defines. Separate multiple defines with spaces.
    void SetComputeShaderDefines(const String& defines);
    /// Set vertex shader define excludes. Use to mark defines that the shader code will not recognize, to prevent compiling redundant shader variations.
    void SetVertexShaderDefineExcludes(const String& excludes);
    /// Set pixel shader define excludes. Use to mark defines that the shader code will not recognize, to prevent compiling redundant shader variations.
    void SetPixelShaderDefineExcludes(const String& excludes);
    /// Set geometry shader define excludes. Use to mark defines that the shader code will not recognize, to prevent compiling redundant shader variations.
    void SetGeometryShaderDefineExcludes(const String& excludes);
    /// Set hull shader define excludes. Use to mark defines that the shader code will not recognize, to prevent compiling redundant shader variations.
    void SetHullShaderDefineExcludes(const String& excludes);
    /// Set domain shader define excludes. Use to mark defines that the shader code will not recognize, to prevent compiling redundant shader variations.
    void SetDomainShaderDefineExcludes(const String& excludes);
    /// Set compute shader define excludes. Use to mark defines that the shader code will not recognize, to prevent compiling redundant shader variations.
    void SetComputeShaderDefineExcludes(const String& excludes);
    /// Reset shader pointers.
    void ReleaseShaders();
    /// Mark shaders loaded this frame.
    void MarkShadersLoaded(unsigned frameNumber);

    /// Return pass name.
    const String& GetName() const { return name_; }

    /// Return pass index. This is used for optimal render-time pass queries that avoid map lookups.
    unsigned GetIndex() const { return index_; }

    /// Return blend mode.
    BlendMode GetBlendMode() const { return blendMode_; }

    /// Return culling mode override. If pass is not overriding culling mode (default), the illegal mode MAX_CULLMODES is returned.
    CullMode GetCullMode() const { return cullMode_; }

    /// Return depth compare mode.
    CompareMode GetDepthTestMode() const { return depthTestMode_; }

    /// Return pass lighting mode.
    PassLightingMode GetLightingMode() const { return lightingMode_; }

    /// Return last shaders loaded frame number.
    unsigned GetShadersLoadedFrameNumber() const { return shadersLoadedFrameNumber_; }

    /// Return depth write mode.
    bool GetDepthWrite() const { return depthWrite_; }

    /// Return alpha-to-coverage mode.
    bool GetAlphaToCoverage() const { return alphaToCoverage_; }

    /// Return whether requires desktop level hardware.
    bool IsDesktop() const { return isDesktop_; }

    /// Return vertex shader name.
    const String& GetVertexShader() const { return vertexShaderName_; }

    /// Return pixel shader name.
    const String& GetPixelShader() const { return pixelShaderName_; }

    /// Return geometry shader name.
    const String& GetGeometryShader() const { return geometryShaderName_; }

    /// Return hull shader name.
    const String& GetHullShader() const { return hullShaderName_; }

    /// Return domain shader name.
    const String& GetDomainShader() const { return domainShaderName_; }

    /// Return compute shader name.
    const String& GetComputeShader() const { return computeShaderName_; }

    /// Return vertex shader defines.
    const String& GetVertexShaderDefines() const { return vertexShaderDefines_; }

    /// Return pixel shader defines.
    const String& GetPixelShaderDefines() const { return pixelShaderDefines_; }

    /// Return geometry shader defines.
    const String& GetGeometryShaderDefines() const { return geometryShaderDefines_; }

    /// Return hull shader defines.
    const String& GetHullShaderDefines() const { return hullShaderDefines_; }

    /// Return domain shader defines.
    const String& GetDomainShaderDefines() const { return domainShaderDefines_; }

    /// Return compute shader defines.
    const String& GetComputeShaderDefines() const { return computeShaderDefines_; }

    /// Return vertex shader define excludes.
    const String& GetVertexShaderDefineExcludes() const { return vertexShaderDefineExcludes_; }

    /// Return pixel shader define excludes.
    const String& GetPixelShaderDefineExcludes() const { return pixelShaderDefineExcludes_; }

    /// Return geometry shader define excludes.
    const String& GetGeometryShaderDefineExcludes() const { return geometryShaderDefineExcludes_; }

    /// Return hull shader define excludes.
    const String& GetHullShaderDefineExcludes() const { return hullShaderDefineExcludes_; }

    /// Return domain shader define excludes.
    const String& GetDomainShaderDefineExcludes() const { return domainShaderDefineExcludes_; }

    /// Return compute shader define excludes.
    const String& GetComputeShaderDefineExcludes() const { return computeShaderDefineExcludes_; }

    /// Return vertex shaders.
    Vector<SharedPtr<ShaderVariation> >& GetVertexShaders() { return vertexShaders_; }

    /// Return pixel shaders.
    Vector<SharedPtr<ShaderVariation> >& GetPixelShaders() { return pixelShaders_; }
    
    /// Return geometry shaders.
    Vector<SharedPtr<ShaderVariation> >& GetGeometryShaders() { return geometryShaders_; }

    /// Return hull shaders.
    Vector<SharedPtr<ShaderVariation> >& GetHullShaders() { return hullShaders_; }

    /// Return domain shaders.
    Vector<SharedPtr<ShaderVariation> >& GetDomainShaders() { return domainShaders_; }

    /// Return compute shaders.
    Vector<SharedPtr<ShaderVariation> >& GetComputeShaders() { return computeShaders_; }

    /// Return vertex shaders with extra defines from the renderpath.
    Vector<SharedPtr<ShaderVariation> >& GetVertexShaders(const StringHash& extraDefinesHash);
    /// Return pixel shaders with extra defines from the renderpath.
    Vector<SharedPtr<ShaderVariation> >& GetPixelShaders(const StringHash& extraDefinesHash);
    /// Return geometry shaders with extra defines from the renderpath.
    Vector<SharedPtr<ShaderVariation> >& GetGeometryShaders(const StringHash& extraDefinesHash);
    /// Return hull shaders with extra defines from the renderpath.
    Vector<SharedPtr<ShaderVariation> >& GetHullShaders(const StringHash& extraDefinesHash);
    /// Return domain shaders with extra defines from the renderpath.
    Vector<SharedPtr<ShaderVariation> >& GetDomainShaders(const StringHash& extraDefinesHash);
    /// Return compute shaders with extra defines from the renderpath.
    Vector<SharedPtr<ShaderVariation> >& GetComputeShaders(const StringHash& extraDefinesHash);

    /// Return the effective vertex shader defines, accounting for excludes. Called internally by Renderer.
    String GetEffectiveVertexShaderDefines() const;
    /// Return the effective pixel shader defines, accounting for excludes. Called internally by Renderer.
    String GetEffectivePixelShaderDefines() const;
    /// Return the effective geometry shader defines, accounting for excludes. Called internally by Renderer.
    String GetEffectiveGeometryShaderDefines() const;
    /// Return the effective hull shader defines, accounting for excludes. Called internally by Renderer.
    String GetEffectiveHullShaderDefines() const;
    /// Return the effective domain shader defines, accounting for excludes. Called internally by Renderer.
    String GetEffectiveDomainShaderDefines() const;
    /// Return the effective compute shader defines, accounting for excludes. Called internally by Renderer.
    String GetEffectiveComputeShaderDefines() const;

private:
    /// Pass index.
    unsigned index_;
    /// Blend mode.
    BlendMode blendMode_;
    /// Culling mode.
    CullMode cullMode_;
    /// Depth compare mode.
    CompareMode depthTestMode_;
    /// Lighting mode.
    PassLightingMode lightingMode_;
    /// Last shaders loaded frame number.
    unsigned shadersLoadedFrameNumber_;
    /// Depth write mode.
    bool depthWrite_;
    /// Alpha-to-coverage mode.
    bool alphaToCoverage_;
    /// Require desktop level hardware flag.
    bool isDesktop_;

    /// Vertex shader name.
    String vertexShaderName_;
    /// Pixel shader name.
    String pixelShaderName_;
    /// Geometry shader name.
    String geometryShaderName_;
    /// Hull shader name.
    String hullShaderName_;
    /// Domain shader name.
    String domainShaderName_;
    /// Compute shader name.
    String computeShaderName_;

    /// Vertex shader defines.
    String vertexShaderDefines_;
    /// Pixel shader defines.
    String pixelShaderDefines_;
    /// Geometry shader defines.
    String geometryShaderDefines_;
    /// Hull shader defines.
    String hullShaderDefines_;
    /// Domain shader defines.
    String domainShaderDefines_;
    /// Compute shader defines.
    String computeShaderDefines_;

    /// Vertex shader define excludes.
    String vertexShaderDefineExcludes_;
    /// Pixel shader define excludes.
    String pixelShaderDefineExcludes_;
    /// Geometry shader define excludes.
    String geometryShaderDefineExcludes_;
    /// Hull shader define excludes.
    String hullShaderDefineExcludes_;
    /// Domain shader define excludes.
    String domainShaderDefineExcludes_;
    /// Compute shader define excludes.
    String computeShaderDefineExcludes_;

    /// Vertex shaders.
    Vector<SharedPtr<ShaderVariation> > vertexShaders_;
    /// Pixel shaders.
    Vector<SharedPtr<ShaderVariation> > pixelShaders_;
    /// Geometry shaders.
    Vector<SharedPtr<ShaderVariation> > geometryShaders_;
    /// Hull shaders.
    Vector<SharedPtr<ShaderVariation> > hullShaders_;
    /// Domain shaders.
    Vector<SharedPtr<ShaderVariation> > domainShaders_;
    /// Compute shaders.
    Vector<SharedPtr<ShaderVariation> > computeShaders_;

	/// Vertex shaders with extra defines from the renderpath.
    HashMap<StringHash, Vector<SharedPtr<ShaderVariation> > > extraVertexShaders_;
    /// Pixel shaders with extra defines from the renderpath.
    HashMap<StringHash, Vector<SharedPtr<ShaderVariation> > > extraPixelShaders_;
    /// Geometry shaders with extra defines from the renderpath.
    HashMap<StringHash, Vector<SharedPtr<ShaderVariation> > > extraGeometryShaders_;
    /// Hull shaders with extra defines from the renderpath.
    HashMap<StringHash, Vector<SharedPtr<ShaderVariation> > > extraHullShaders_;
    /// Domain shaders with extra defines from the renderpath.
    HashMap<StringHash, Vector<SharedPtr<ShaderVariation> > > extraDomainShaders_;
    /// Compute shaders with extra defines from the renderpath.
    HashMap<StringHash, Vector<SharedPtr<ShaderVariation> > > extraComputeShaders_;

	
    /// Pass name.
    String name_;
};

/// %Material technique. Consists of several passes.
class ATOMIC_API Technique : public Resource
{
    ATOMIC_OBJECT(Technique, Resource);

    friend class Renderer;

public:
    /// Construct.
    Technique(Context* context);
    /// Destruct.
    ~Technique();
    /// Register object factory.
    static void RegisterObject(Context* context);

    /// Load resource from stream. May be called from a worker thread. Return true if successful.
    virtual bool BeginLoad(Deserializer& source);

    /// Set whether requires desktop level hardware.
    void SetIsDesktop(bool enable);
    /// Create a new pass.
    Pass* CreatePass(const String& passName);
    /// Remove a pass.
    void RemovePass(const String& passName);
    /// Reset shader pointers in all passes.
    void ReleaseShaders();
    /// Clone the technique. Passes will be deep copied to allow independent modification.
    SharedPtr<Technique> Clone(const String& cloneName = String::EMPTY) const;

    /// Return whether requires desktop level hardware.
    bool IsDesktop() const { return isDesktop_; }

    /// Return whether technique is supported by the current hardware.
    bool IsSupported() const { return !isDesktop_ || desktopSupport_; }

    /// Return whether has a pass.
    bool HasPass(unsigned passIndex) const { return passIndex < passes_.Size() && passes_[passIndex].Get() != 0; }

    /// Return whether has a pass by name. This overload should not be called in time-critical rendering loops; use a pre-acquired pass index instead.
    bool HasPass(const String& passName) const;

    /// Return a pass, or null if not found.
    Pass* GetPass(unsigned passIndex) const { return passIndex < passes_.Size() ? passes_[passIndex].Get() : 0; }

    /// Return a pass by name, or null if not found. This overload should not be called in time-critical rendering loops; use a pre-acquired pass index instead.
    Pass* GetPass(const String& passName) const;

    /// Return a pass that is supported for rendering, or null if not found.
    Pass* GetSupportedPass(unsigned passIndex) const
    {
        Pass* pass = passIndex < passes_.Size() ? passes_[passIndex].Get() : 0;
        return pass && (!pass->IsDesktop() || desktopSupport_) ? pass : 0;
    }

    /// Return a supported pass by name. This overload should not be called in time-critical rendering loops; use a pre-acquired pass index instead.
    Pass* GetSupportedPass(const String& passName) const;

    /// Return number of passes.
    unsigned GetNumPasses() const;
    /// Return all pass names.
    Vector<String> GetPassNames() const;
    /// Return all passes.
    PODVector<Pass*> GetPasses() const;

    /// Return a clone with added shader compilation defines. Called internally by Material.
    SharedPtr<Technique> CloneWithDefines(const String& vsDefines, const String& psDefines, const String& gsDefines, const String& hsDefines, const String& dsDefines, const String& csDefines);

    /// Return a pass type index by name. Allocate new if not used yet.
    static unsigned GetPassIndex(const String& passName);

    /// Index for base pass. Initialized once GetPassIndex() has been called for the first time.
    static unsigned basePassIndex;
    /// Index for alpha pass. Initialized once GetPassIndex() has been called for the first time.
    static unsigned alphaPassIndex;
    /// Index for prepass material pass. Initialized once GetPassIndex() has been called for the first time.
    static unsigned materialPassIndex;
    /// Index for deferred G-buffer pass. Initialized once GetPassIndex() has been called for the first time.
    static unsigned deferredPassIndex;
    /// Index for per-pixel light pass. Initialized once GetPassIndex() has been called for the first time.
    static unsigned lightPassIndex;
    /// Index for lit base pass. Initialized once GetPassIndex() has been called for the first time.
    static unsigned litBasePassIndex;
    /// Index for lit alpha pass. Initialized once GetPassIndex() has been called for the first time.
    static unsigned litAlphaPassIndex;
    /// Index for shadow pass. Initialized once GetPassIndex() has been called for the first time.
    static unsigned shadowPassIndex;

private:
    /// Require desktop GPU flag.
    bool isDesktop_;
    /// Cached desktop GPU support flag.
    bool desktopSupport_;
    /// Passes.
    Vector<SharedPtr<Pass> > passes_;
    /// Cached clones with added shader compilation defines.
    //HashMap<Pair<StringHash, StringHash>, SharedPtr<Technique> > cloneTechniques_;
    HashMap<SharedArrayPtr<StringHash>, SharedPtr<Technique> > cloneTechniques_;

    /// Pass index assignments.
    static HashMap<String, unsigned> passIndices;
};

}
