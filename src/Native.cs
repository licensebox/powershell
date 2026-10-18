#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

namespace Licensebox.PowerShellNative;

public sealed class LicenseboxException(string code,string detail) : Exception("licensebox: "+detail)
{
    public string Code { get; }=code;
}

public sealed class Config(string product,IReadOnlyDictionary<string,string> keys)
{
    public string Product { get; }=product;
    public IReadOnlyDictionary<string,string> Keys { get; }=keys;
    public string Version { get; set; }="";
    public string? Server { get; set; }
    public string? Directory { get; set; }
    public string? CaBundle { get; set; }
    public Action<string,string>? OnSignIn { get; set; }
    public Func<bool>? Cancelled { get; set; }
    /// Trusted platform/test seams. Never accept a binding from an end user.
    public Func<string>? MachineBinding { get; set; }
    public Func<double>? Clock { get; set; }
}

/// Owns a C >=0.3 client; use using/Dispose. Linux is the validated platform.
/// PowerShell uses these synchronous P/Invoke primitives. Callbacks must not reenter it.
public class Client : IDisposable
{
    private const string Library="licensebox";
    static Client() {
        NativeLibrary.SetDllImportResolver(typeof(Client).Assembly,(name,assembly,path)=> {
            if(name!=Library)return IntPtr.Zero;
            var file=Environment.GetEnvironmentVariable("LICENSEBOX_LIBRARY");
            var dir=Environment.GetEnvironmentVariable("LICENSEBOX_LIB_DIR");
            if(file is null && dir is not null)file=System.IO.Path.Combine(dir,"liblicensebox.so");
            return file is null?IntPtr.Zero:NativeLibrary.Load(file);
        });
    }
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate void SignInFn(IntPtr context,IntPtr url,IntPtr code);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate double ClockFn(IntPtr context);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate int BindingFn(IntPtr context,IntPtr output,nuint capacity);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate int CancelFn(IntPtr context);
    [StructLayout(LayoutKind.Sequential)]
    private struct Callbacks
    {
        public IntPtr Context;
        public SignInFn? OnSignIn;
        public ClockFn? Clock;
        public BindingFn? Binding;
        public CancelFn? Cancelled;
    }
    private static class Native
    {
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern int lb_client_create_json([MarshalAs(UnmanagedType.LPUTF8Str)] string options,ref Callbacks callbacks,out IntPtr output);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern int lb_client_call_json(IntPtr client,[MarshalAs(UnmanagedType.LPUTF8Str)] string operation,[MarshalAs(UnmanagedType.LPUTF8Str)] string args,out IntPtr output);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern void lb_client_destroy(IntPtr client);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern IntPtr lb_error_code(IntPtr client);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern IntPtr lb_error_message(IntPtr client);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern IntPtr lb_result_code(int result);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern void lb_free(IntPtr output);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern int lb_native_binding([MarshalAs(UnmanagedType.LPUTF8Str)] string product,byte[] output,nuint capacity);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern int lb_derive_binding([MarshalAs(UnmanagedType.LPUTF8Str)] string product,[MarshalAs(UnmanagedType.LPUTF8Str)] string source,[MarshalAs(UnmanagedType.LPUTF8Str)] string raw,byte[] output,nuint capacity);
        [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] internal static extern int lb_verify_lease_json([MarshalAs(UnmanagedType.LPUTF8Str)] string token,[MarshalAs(UnmanagedType.LPUTF8Str)] string product,[MarshalAs(UnmanagedType.LPUTF8Str)] string keys,double now,out IntPtr output);
    }
    private sealed class State
    {
        internal Exception? Failure;
        internal readonly Callbacks Callbacks;
        internal State(Config cfg)
        {
            if(cfg.OnSignIn is {} signin) Callbacks.OnSignIn=(_,url,code)=>{try{signin(Text(url),Text(code));}catch(Exception e){Failure=e;}};
            if(cfg.Clock is {} clock) Callbacks.Clock=_=>{try{double now=clock();if(!double.IsFinite(now))throw new ArgumentException("invalid clock result");return now;}catch(Exception e){Failure=e;return 0;}};
            if(cfg.MachineBinding is {} binding) Callbacks.Binding=(_,output,capacity)=>{try{byte[] bytes=Encoding.UTF8.GetBytes(Argument(binding()));if((nuint)bytes.Length>=capacity)return 1;Marshal.Copy(bytes,0,output,bytes.Length);Marshal.WriteByte(output,bytes.Length,0);return 0;}catch(Exception e){Failure=e;return 1;}};
            Callbacks.Cancelled=_=>{if(Failure is not null)return 1;try{return cfg.Cancelled?.Invoke()==true?1:0;}catch(Exception e){Failure=e;return 1;}};
        }
    }
    private readonly object mutex=new();
    private readonly State state;
    private IntPtr handle;
    private bool busy;
    public Client(Config cfg)
    {
        var options=new Dictionary<string,object>{{"product",Argument(cfg.Product)},{"keys",cfg.Keys.ToDictionary(pair=>Argument(pair.Key),pair=>Argument(pair.Value))},{"version",Argument(cfg.Version)}};
        if(cfg.Server is {} server) options["server"]=Argument(server);
        if(cfg.Directory is {} directory)options["directory"]=Argument(directory);
        if(cfg.CaBundle is {} caBundle)options["ca_bundle"]=Argument(caBundle);
        state=new State(cfg);var callbacks=state.Callbacks;
        int result=Native.lb_client_create_json(JsonSerializer.Serialize(options),ref callbacks,out handle);
        GC.KeepAlive(state);
        if(result!=0 || state.Failure is not null){if(handle!=IntPtr.Zero){Native.lb_client_destroy(handle);handle=IntPtr.Zero;}if(state.Failure is not null)throw new LicenseboxException("callback_error","application callback failed");throw ResultError(result,IntPtr.Zero);}
    }
    private static string Argument(string value)
    {
        if(value is null||value.Contains('\0'))throw new LicenseboxException("invalid_argument","null/NUL argument");
        return value;
    }
    private static string Text(IntPtr value)=>Marshal.PtrToStringUTF8(value)??"";
    private static LicenseboxException ResultError(int result,IntPtr client)
    {
        string code=Text(Native.lb_result_code(result)),message=code;
        if(client!=IntPtr.Zero&&code!="invalid_argument") {string saved=Text(Native.lb_error_code(client));if(saved!="ok")code=saved;message=Text(Native.lb_error_message(client));}
        return new LicenseboxException(code,message);
    }
    private static JsonElement Output(IntPtr value)
    {
        if(value==IntPtr.Zero)throw new LicenseboxException("protocol_error","missing native result");
        try{using var json=JsonDocument.Parse(Text(value));return json.RootElement.Clone();}
        finally{Native.lb_free(value);}
    }
    private JsonElement Call(string operation,object? arguments=null)
    {
        lock(mutex)
        {
            ObjectDisposedException.ThrowIf(handle==IntPtr.Zero,this);
            if(busy)throw new InvalidOperationException("callbacks must not reenter the client");
            busy=true;
            try
            {
                int result=Native.lb_client_call_json(handle,operation,JsonSerializer.Serialize(arguments??new{}),out var output);
                if(state.Failure is not null||result!=0)
                {
                    Native.lb_free(output);
                    if(state.Failure is {} failure){state.Failure=null;throw new LicenseboxException("callback_error","application callback failed: "+failure.GetType().Name);}
                    throw ResultError(result,handle);
                }
                return Output(output);
            }
            finally{busy=false;GC.KeepAlive(this);}
        }
    }
    public JsonElement Lease()=>Call("lease");
    public JsonElement Heartbeat(string module)=>Call("heartbeat",new{module=Argument(module)});
    public JsonElement Require(string module)=>Call("require",new{module=Argument(module)});
    public JsonElement Status()=>Call("status");
    public JsonElement SignIn(double timeoutSeconds=0) {if(!double.IsFinite(timeoutSeconds))throw new ArgumentException("invalid timeout");return Call("sign_in",new{timeout=timeoutSeconds});}
    public void Logout()=>Call("logout");
    public JsonElement Modules()=>Call("modules");
    public JsonElement Requests()=>Call("requests");
    public JsonElement RequestAccess(IEnumerable<string> modules,string note="")=>Call("request",new{modules=modules.Select(Argument).ToArray(),note=Argument(note)});
    public string AccessLink()=>Call("access-link").GetString()??throw new LicenseboxException("protocol_error","invalid access link");
    public void Record(string command,bool success,double elapsedSeconds) {if(!double.IsFinite(elapsedSeconds)||elapsedSeconds<0)throw new ArgumentException("invalid elapsed time");Call("record",new{command=Argument(command),success,elapsed=elapsedSeconds});}
    public void Dispose(){lock(mutex){if(busy)throw new InvalidOperationException("callbacks must not reenter the client");if(handle!=IntPtr.Zero){Native.lb_client_destroy(handle);handle=IntPtr.Zero;}GC.SuppressFinalize(this);}}
    ~Client(){if(handle!=IntPtr.Zero)Native.lb_client_destroy(handle);}
    public static string DeriveBinding(string product,string source,string raw)
    {
        raw=raw.TrimEnd('\0');if(raw.Contains('\0'))throw new LicenseboxException("identity_unavailable","invalid native identity");
        byte[] output=new byte[128];int result=Native.lb_derive_binding(Argument(product),Argument(source),raw,output,(nuint)output.Length);
        if(result!=0)throw ResultError(result,IntPtr.Zero);return Encoding.UTF8.GetString(output,0,Array.IndexOf(output,(byte)0));
    }
    public static string NativeBinding(string product)
    {
        byte[] output=new byte[128];int result=Native.lb_native_binding(Argument(product),output,(nuint)output.Length);
        if(result!=0)throw ResultError(result,IntPtr.Zero);return Encoding.UTF8.GetString(output,0,Array.IndexOf(output,(byte)0));
    }
    public static JsonElement VerifyLease(string token,string product,IReadOnlyDictionary<string,string> keys,double now)
    {
        if(!double.IsFinite(now))throw new ArgumentException("invalid time");
        int result=Native.lb_verify_lease_json(Argument(token),Argument(product),JsonSerializer.Serialize(keys),now,out var output);
        if(result!=0){Native.lb_free(output);throw ResultError(result,IntPtr.Zero);}return Output(output);
    }
}
