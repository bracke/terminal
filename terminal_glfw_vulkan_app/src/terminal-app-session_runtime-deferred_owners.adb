separate (Terminal.App.Session_Runtime)
protected body Deferred_Owners is
   procedure Admit_Resources
     (Item     : in out Deferred_Resource_Set_Access;
      Accepted : out Boolean) is
   begin
      Accepted := Accepting;
      if Accepted then
         Retain_Resources (Item);
      end if;
   end Admit_Resources;

   procedure Retain_Resources
     (Item : in out Deferred_Resource_Set_Access) is
   begin
      if Item /= null then
         if Resources = Natural'Last then
            raise Storage_Error with "deferred resource count overflow";
         end if;
         Item.Next := null;
         if Resource_Tail = null then
            Resource_Head := Item;
         else
            Resource_Tail.Next := Item;
         end if;
         Resource_Tail := Item;
         Item := null;
         Resources := Resources + 1;
      end if;
   end Retain_Resources;

   procedure Take_Resources
     (Lease : in out Deferred_Resource_Lease) is
   begin
      Lease.Item := Resource_Head;
      if Lease.Item /= null then
         if In_Flight = Natural'Last then
            raise Storage_Error with "deferred in-flight count overflow";
         end if;
         Resource_Head := Lease.Item.Next;
         Lease.Item.Next := null;
         if Resource_Head = null then
            Resource_Tail := null;
         end if;
         if Resources > 0 then
            Resources := Resources - 1;
         end if;
         In_Flight := In_Flight + 1;
         Lease.Active := True;
      end if;
   end Take_Resources;

   procedure Admit_Runtime
     (Item     : in out Runtime_Access;
      Accepted : out Boolean) is
   begin
      Accepted := Accepting;
      if Accepted then
         Retain_Runtime (Item);
      end if;
   end Admit_Runtime;

   procedure Retain_Runtime (Item : in out Runtime_Access) is
   begin
      if Item /= null then
         if Runtimes = Natural'Last then
            raise Storage_Error with "deferred runtime count overflow";
         end if;
         Item.Deferred_Next := null;
         if Runtime_Tail = null then
            Runtime_Head := Item;
         else
            Runtime_Tail.Deferred_Next := Item;
         end if;
         Runtime_Tail := Item;
         Item := null;
         Runtimes := Runtimes + 1;
      end if;
   end Retain_Runtime;

   procedure Take_Runtime (Lease : in out Deferred_Runtime_Lease) is
   begin
      Lease.Item := Runtime_Head;
      if Lease.Item /= null then
         if In_Flight = Natural'Last then
            raise Storage_Error with "deferred in-flight count overflow";
         end if;
         Runtime_Head := Lease.Item.Deferred_Next;
         Lease.Item.Deferred_Next := null;
         if Runtime_Head = null then
            Runtime_Tail := null;
         end if;
         if Runtimes > 0 then
            Runtimes := Runtimes - 1;
         end if;
         In_Flight := In_Flight + 1;
         Lease.Active := True;
      end if;
   end Take_Runtime;

   procedure Try_Begin_Drain (Acquired : out Boolean) is
   begin
      Acquired := not Draining;
      if Acquired then
         Draining := True;
      end if;
   end Try_Begin_Drain;

   procedure Finish_Owner is
   begin
      if In_Flight = 0 then
         raise Program_Error with "deferred cleanup owner underflow";
      end if;
      In_Flight := In_Flight - 1;
   end Finish_Owner;

   procedure End_Drain is
   begin
      Draining := False;
   end End_Drain;

   procedure Register_Producer (Registered : out Boolean) is
   begin
      Registered := False;
      if not Accepting then
         return;
      elsif Producers = Natural'Last then
         raise Storage_Error with "cleanup producer count overflow";
      end if;
      Producers := Producers + 1;
      Registered := True;
   end Register_Producer;

   procedure Finish_Producer is
   begin
      if Producers = 0 then
         raise Program_Error with "cleanup producer count underflow";
      end if;
      Producers := Producers - 1;
   end Finish_Producer;

   procedure Stop_Accepting is
   begin
      Accepting := False;
   end Stop_Accepting;

   function Complete return Boolean is
     (Resources = 0
      and then Runtimes = 0
      and then In_Flight = 0
      and then (Accepting or else Producers = 0));

   function Resource_Count return Natural is (Resources);
   function Runtime_Count return Natural is (Runtimes);

   function Runtime_Retry_Delayed return Boolean is
     (Runtime_Head /= null
      and then Runtime_Head.Deferred_Retry.Delay_Milliseconds > 0
      and then Runtime_Head.Deferred_Retry.Retry_After
        /= Ada.Real_Time.Time_First);
end Deferred_Owners;
