using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace Win32 {
    public class OleAut32 {
        // Define the Win32 API call to load the TypeLib from a DLL
        [DllImport("oleaut32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        public static extern void LoadTypeLib(
            [MarshalAs(UnmanagedType.LPWStr)] string fileName, 
            out ITypeLib typeLib
        );
    }
}