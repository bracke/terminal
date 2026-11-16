with Interfaces.C;
with Interfaces.C.Strings;
with Terminal.Common.C_Strings;

package body Terminal.App.Global_Hotkey is
   package C renames Interfaces.C;
   package CStr renames Interfaces.C.Strings;
   use type C.int;

   function Native_Register (Binding : CStr.chars_ptr) return C.int
     with Import, Convention => C,
          External_Name => "bracke_global_hotkey_register";
   procedure Native_Unregister
     with Import, Convention => C,
          External_Name => "bracke_global_hotkey_unregister";
   function Native_Poll return C.int
     with Import, Convention => C,
          External_Name => "bracke_global_hotkey_poll";

   procedure Register (Binding : String; Status : out Register_Status) is
      Value : Terminal.Common.C_Strings.Owner;
      Result : C.int;
   begin
      if Binding = "" then
         Unregister;
         Status := Disabled;
         return;
      end if;
      Terminal.Common.C_Strings.Set (Value, Binding);
      Result := Native_Register
        (Terminal.Common.C_Strings.Unsafe_Pointer (Value));
      Status :=
        (case Result is
           when 1 => Registered,
           when -1 => Invalid_Binding,
           when -2 => Unsupported,
           when others => Registration_Failed);
   end Register;

   procedure Unregister is
   begin
      Native_Unregister;
   end Unregister;

   function Poll return Boolean is (Native_Poll /= 0);
end Terminal.App.Global_Hotkey;
