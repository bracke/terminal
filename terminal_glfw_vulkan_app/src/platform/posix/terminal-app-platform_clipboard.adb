with Interfaces.C;
with System;
with Terminal.Core;

package body Terminal.App.Platform_Clipboard is
   package C renames Interfaces.C;
   use type C.int;
   use type C.size_t;

   type C_Byte_Array is
     array (Natural range <>) of aliased C.unsigned_char;
   pragma Convention (C, C_Byte_Array);

   function C_Available return C.int
   with Import, Convention => C,
        External_Name => "terminal_primary_clipboard_available";

   function C_Set
     (Data   : System.Address;
      Length : C.size_t) return C.int
   with Import, Convention => C,
        External_Name => "terminal_primary_clipboard_set";

   function C_Get
     (Data      : access C.unsigned_char;
      Capacity  : C.size_t;
      Length    : access C.size_t) return C.int
   with Import, Convention => C,
        External_Name => "terminal_primary_clipboard_get";

   function Primary_Available return Boolean is
     (C_Available /= 0);

   procedure Set_Primary
     (Text   : String;
      Status : out Operation_Status)
   is
      Result : C.int;
   begin
      if not Primary_Available then
         Status := Unavailable;
         return;
      end if;
      Result := C_Set
        ((if Text'Length = 0 then System.Null_Address else Text'Address),
         C.size_t (Text'Length));
      Status := (if Result = 1 then Ok else Failed);
   end Set_Primary;

   function Primary_Text
     (Status : out Operation_Status) return String
   is
      Buffer : C_Byte_Array (0 .. Terminal.Core.Max_Clipboard_Length - 1) :=
        (others => 0);
      Length : aliased C.size_t := 0;
      Result : C.int;
   begin
      if not Primary_Available then
         Status := Unavailable;
         return "";
      end if;

      Result := C_Get
        (Buffer (0)'Access, C.size_t (Buffer'Length), Length'Access);
      if Result = 0 then
         Status := Failed;
         return "";
      end if;

      declare
         Count : constant Natural :=
           Natural'Min (Natural (Length), Buffer'Length);
         Text : String (1 .. Count);
      begin
         for I in 1 .. Count loop
            Text (I) := Character'Val (Buffer (I - 1));
         end loop;
         Status := (if Result = 2 then Truncated else Ok);
         return Text;
      end;
   end Primary_Text;
end Terminal.App.Platform_Clipboard;
