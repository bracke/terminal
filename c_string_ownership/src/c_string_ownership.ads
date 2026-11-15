with Ada.Finalization;
with Interfaces.C.Strings;

package C_String_Ownership is
   type Owner is new Ada.Finalization.Limited_Controlled with private;

   --  Replace the current value, if any, while preserving ownership if the new
   --  allocation fails.
   procedure Set (Item : in out Owner; Value : String);
   procedure Release (Item : in out Owner);

   --  The returned pointer does not retain Item. It is valid only until the
   --  next Set, Release, or finalization of Item.
   function Unsafe_Pointer
     (Item : Owner) return Interfaces.C.Strings.chars_ptr;

private
   type Owner is new Ada.Finalization.Limited_Controlled with record
      Value : aliased Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
   end record;

   overriding procedure Finalize (Item : in out Owner);
end C_String_Ownership;
