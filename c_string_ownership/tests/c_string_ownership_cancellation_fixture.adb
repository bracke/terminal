package body C_String_Ownership_Cancellation_Fixture is
   protected body Synchronization is
      procedure Publish is
      begin
         Published := True;
      end Publish;

      entry Wait_For_Publication when Published is
      begin
         null;
      end Wait_For_Publication;

      entry Wait_For_Return when Return_Allowed is
      begin
         null;
      end Wait_For_Return;

      procedure Allow_Return is
      begin
         Return_Allowed := True;
      end Allow_Return;

      procedure Record_Abort (Observed : Boolean) is
      begin
         Setter_Abnormal := Observed;
         Abort_Recorded := True;
      end Record_Abort;

      entry Wait_For_Abort (Observed : out Boolean) when Abort_Recorded is
      begin
         Observed := Setter_Abnormal;
      end Wait_For_Abort;
   end Synchronization;

   procedure Notify_Allocation_Published is
   begin
      Synchronization.Publish;
   end Notify_Allocation_Published;

   procedure Wait_For_Allocation_Return is
   begin
      Synchronization.Wait_For_Return;
   end Wait_For_Allocation_Return;
end C_String_Ownership_Cancellation_Fixture;
