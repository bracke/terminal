with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body C_String_Ownership is
   use type Interfaces.C.int;
   use type Interfaces.C.Strings.chars_ptr;

   function Allocate_Owned
     (Target : access Interfaces.C.Strings.chars_ptr;
      Source : System.Address;
      Length : Interfaces.C.size_t) return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "c_string_ownership_allocate_owned";

   procedure Free_Owned
     (Target : access Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C,
          External_Name => "c_string_ownership_free_owned";

   protected Ownership_Publication is
      procedure Replace (Target, Replacement : in out Owner);
   end Ownership_Publication;

   protected body Ownership_Publication is
      procedure Replace (Target, Replacement : in out Owner) is
         Previous : constant Interfaces.C.Strings.chars_ptr := Target.Value;
      begin
         Target.Value := Replacement.Value;
         Replacement.Value := Previous;
      end Replace;
   end Ownership_Publication;

   procedure Set (Item : in out Owner; Value : String) is
      Replacement : Owner;
      Result      : Interfaces.C.int;
   begin
      Result := Allocate_Owned
        (Replacement.Value'Access,
         Value'Address,
         Interfaces.C.size_t (Value'Length));
      if Result = 0 then
         raise Storage_Error with "could not allocate owned C string";
      elsif Replacement.Value = Interfaces.C.Strings.Null_Ptr then
         raise Program_Error with
           "C string allocator reported success without publishing ownership";
      end if;
      Ownership_Publication.Replace (Item, Replacement);
   end Set;

   procedure Release (Item : in out Owner) is
   begin
      if Item.Value /= Interfaces.C.Strings.Null_Ptr then
         Free_Owned (Item.Value'Access);
      end if;
   end Release;

   function Unsafe_Pointer
     (Item : Owner) return Interfaces.C.Strings.chars_ptr is
     (Item.Value);

   overriding procedure Finalize (Item : in out Owner) is
   begin
      Release (Item);
   end Finalize;
end C_String_Ownership;
