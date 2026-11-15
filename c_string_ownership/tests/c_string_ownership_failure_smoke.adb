with C_String_Ownership;
with C_String_Ownership_Cancellation_Fixture;
with Interfaces.C;
with Interfaces.C.Strings;

procedure C_String_Ownership_Failure_Smoke is
   package Cancellation_Fixture renames
     C_String_Ownership_Cancellation_Fixture;

   use type Interfaces.C.Strings.chars_ptr;
   use type Interfaces.C.int;

   procedure Fail_Next_Allocation
     with Import, Convention => C,
          External_Name => "test_c_string_ownership_fail_next_allocation";

   procedure Break_Next_Publication
     with Import, Convention => C,
          External_Name => "test_c_string_ownership_break_next_publication";

   procedure Block_Next_Allocation
     with Import, Convention => C,
          External_Name => "test_c_string_ownership_block_next_allocation";

   function Live_Allocation_Count return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "test_c_string_ownership_live_allocation_count";

   Item : C_String_Ownership.Owner;

   procedure Check_Preserved is
   begin
      if C_String_Ownership.Unsafe_Pointer (Item) =
        Interfaces.C.Strings.Null_Ptr
        or else Interfaces.C.Strings.Value
          (C_String_Ownership.Unsafe_Pointer (Item)) /= "preserved"
      then
         raise Program_Error with
           "failed replacement lost the owned C string";
      end if;
   end Check_Preserved;

   procedure Check_Live_Allocations
     (Expected : Interfaces.C.int;
      Context  : String) is
   begin
      if Live_Allocation_Count /= Expected then
         raise Program_Error with Context & " leaked or double-freed ownership";
      end if;
   end Check_Live_Allocations;

   procedure Check_Cancelled_Replacement is
      Pointer : constant Interfaces.C.Strings.chars_ptr :=
        C_String_Ownership.Unsafe_Pointer (Item);
   begin
      if Pointer = Interfaces.C.Strings.Null_Ptr
        or else Interfaces.C.Strings.Value (Pointer) not in
          "preserved" | "cancelled replacement"
      then
         raise Program_Error with
           "cancellation left the C string owner in an invalid state";
      end if;
   end Check_Cancelled_Replacement;
begin
   C_String_Ownership.Set (Item, "preserved");
   Check_Live_Allocations (1, "initial allocation");

   Fail_Next_Allocation;
   begin
      C_String_Ownership.Set (Item, "must not replace");
      raise Program_Error with "injected allocation failure was ignored";
   exception
      when Storage_Error => null;
   end;
   Check_Preserved;
   Check_Live_Allocations (1, "failed allocation");

   Break_Next_Publication;
   declare
      Rejected : Boolean := False;
   begin
      begin
         C_String_Ownership.Set (Item, "must not publish null");
      exception
         when Program_Error => Rejected := True;
      end;
      if not Rejected then
         raise Program_Error with "broken allocator publication was accepted";
      end if;
   end;
   Check_Preserved;
   Check_Live_Allocations (1, "invalid publication");

   Block_Next_Allocation;
   declare
      Abort_Observed : Boolean := False;

      task Setter;
      task Aborter is
         entry Start;
      end Aborter;

      task body Setter is
      begin
         C_String_Ownership.Set (Item, "cancelled replacement");
      end Setter;

      task body Aborter is
      begin
         accept Start;
         abort Setter;
         Cancellation_Fixture.Synchronization.Record_Abort
           (not Setter'Callable);
      end Aborter;
   begin
      select
         Cancellation_Fixture.Synchronization.Wait_For_Publication;
      or
         delay 5.0;
         Aborter.Start;
         Cancellation_Fixture.Synchronization.Allow_Return;
         raise Program_Error with
           "cancellation fixture did not publish its allocation";
      end select;

      Aborter.Start;
      select
         Cancellation_Fixture.Synchronization.Wait_For_Abort
           (Abort_Observed);
      or
         delay 5.0;
         Cancellation_Fixture.Synchronization.Allow_Return;
         abort Setter;
         raise Program_Error with
           "abort request did not complete while allocation was blocked";
      end select;
      Cancellation_Fixture.Synchronization.Allow_Return;

      if not Abort_Observed then
         abort Setter;
         raise Program_Error with
           "setter did not become abnormal before allocation returned";
      end if;
   end;
   Check_Cancelled_Replacement;
   Check_Live_Allocations (1, "cancelled replacement");

   C_String_Ownership.Release (Item);
   Check_Live_Allocations (0, "explicit release");
end C_String_Ownership_Failure_Smoke;
