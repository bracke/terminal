package C_String_Ownership_Cancellation_Fixture is
   protected Synchronization is
      procedure Publish;
      entry Wait_For_Publication;
      entry Wait_For_Return;
      procedure Allow_Return;
      procedure Record_Abort (Observed : Boolean);
      entry Wait_For_Abort (Observed : out Boolean);
   private
      Published       : Boolean := False;
      Return_Allowed  : Boolean := False;
      Abort_Recorded  : Boolean := False;
      Setter_Abnormal : Boolean := False;
   end Synchronization;

   procedure Notify_Allocation_Published
     with Export, Convention => C,
          External_Name =>
            "test_c_string_ownership_notify_allocation_published";
   procedure Wait_For_Allocation_Return
     with Export, Convention => C,
          External_Name => "test_c_string_ownership_wait_for_allocation_return";
end C_String_Ownership_Cancellation_Fixture;
