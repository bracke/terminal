with C_String_Ownership;
with Interfaces.C;
with Interfaces.C.Strings;

procedure C_String_Ownership_Smoke is
   use type Interfaces.C.int;
   use type Interfaces.C.Strings.chars_ptr;

   function Contract_Test return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "test_c_string_ownership_contract";

   Item : C_String_Ownership.Owner;
begin
   if Contract_Test = 0 then
      raise Program_Error with "owned C string publication contract failed";
   end if;

   C_String_Ownership.Set (Item, "owned value");
   if C_String_Ownership.Unsafe_Pointer (Item) =
     Interfaces.C.Strings.Null_Ptr
     or else Interfaces.C.Strings.Value
       (C_String_Ownership.Unsafe_Pointer (Item)) /= "owned value"
   then
      raise Program_Error with "owned C string was not published";
   end if;

   C_String_Ownership.Set (Item, "replacement");
   if Interfaces.C.Strings.Value
       (C_String_Ownership.Unsafe_Pointer (Item)) /= "replacement"
   then
      raise Program_Error with "owned C string was not replaced";
   end if;

   C_String_Ownership.Release (Item);
   if C_String_Ownership.Unsafe_Pointer (Item) /=
     Interfaces.C.Strings.Null_Ptr
   then
      raise Program_Error with "released C string retained its marker";
   end if;

   C_String_Ownership.Set (Item, "");
   if Interfaces.C.Strings.Value
       (C_String_Ownership.Unsafe_Pointer (Item)) /= ""
   then
      raise Program_Error with "empty C string was not terminated";
   end if;
end C_String_Ownership_Smoke;
