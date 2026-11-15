package body Terminal.App.Child_Tracker is
   protected body Registry is
      function Count return Natural is (Item_Count);

      function Admission_Load return Natural is (Admission_Load_Value);

      procedure Reserve (Item : in out Reservation) is
      begin
         if Item.Active then
            raise Program_Error with "child reservation is already active";
         end if;
         Item.Active :=
           Item_Count + Reservations < Max_Tracked_Children
           and then Admission_Load_Value + Reservations < Max_Admission_Load;
         if Item.Active then
            Reservations := Reservations + 1;
            Item.Owner := Registry'Unchecked_Access;
         end if;
      end Reserve;

      procedure Commit
        (Process : Process_ID;
         Item    : in out Reservation) is
      begin
         if Process = 0
           or else not Item.Active
           or else Item.Owner /= Registry'Unchecked_Access
           or else Reservations = 0
         then
            raise Program_Error with "invalid child-registry reservation";
         end if;
         Reservations := Reservations - 1;
         Item_Count := Item_Count + 1;
         Admission_Load_Value := Admission_Load_Value + 1;
         Items (Item_Count) := Process;
         Poll_Error_Reported (Item_Count) := False;
         Counts_Against_Limit (Item_Count) := True;
         Item.Active := False;
         Item.Owner := null;
      end Commit;

      procedure Cancel (Item : in out Reservation) is
      begin
         if not Item.Active
           or else Item.Owner /= Registry'Unchecked_Access
           or else Reservations = 0
         then
            raise Program_Error with "missing child-registry reservation";
         end if;
         Reservations := Reservations - 1;
         Item.Active := False;
         Item.Owner := null;
      end Cancel;

      procedure Snapshot
        (Items : out Process_ID_Array;
         Count : out Natural) is
      begin
         Items := Registry.Items;
         Count := Item_Count;
      end Snapshot;

      procedure Note_Poll_Error
        (Process      : Process_ID;
         First_Report : out Boolean) is
      begin
         First_Report := False;
         for I in 1 .. Item_Count loop
            if Items (I) = Process then
               First_Report := not Poll_Error_Reported (I);
               Poll_Error_Reported (I) := True;
               if Counts_Against_Limit (I) then
                  Counts_Against_Limit (I) := False;
                  Admission_Load_Value := Admission_Load_Value - 1;
               end if;
               return;
            end if;
         end loop;
      end Note_Poll_Error;

      procedure Note_Poll_Success (Process : Process_ID) is
      begin
         for I in 1 .. Item_Count loop
            if Items (I) = Process then
               Poll_Error_Reported (I) := False;
               if not Counts_Against_Limit (I) then
                  Counts_Against_Limit (I) := True;
                  Admission_Load_Value := Admission_Load_Value + 1;
               end if;
               return;
            end if;
         end loop;
      end Note_Poll_Success;

      procedure Remove (Process : Process_ID) is
      begin
         for I in 1 .. Item_Count loop
            if Items (I) = Process then
               if Counts_Against_Limit (I) then
                  Admission_Load_Value := Admission_Load_Value - 1;
               end if;
               if I < Item_Count then
                  Items (I .. Item_Count - 1) := Items (I + 1 .. Item_Count);
                  Poll_Error_Reported (I .. Item_Count - 1) :=
                    Poll_Error_Reported (I + 1 .. Item_Count);
                  Counts_Against_Limit (I .. Item_Count - 1) :=
                    Counts_Against_Limit (I + 1 .. Item_Count);
               end if;
               Items (Item_Count) := 0;
               Poll_Error_Reported (Item_Count) := False;
               Counts_Against_Limit (Item_Count) := False;
               Item_Count := Item_Count - 1;
               return;
            end if;
         end loop;
      end Remove;

   end Registry;

   function Granted (Item : Reservation) return Boolean is (Item.Active);

   overriding procedure Finalize (Item : in out Reservation) is
   begin
      if Item.Active and then Item.Owner /= null then
         Item.Owner.Cancel (Item);
      end if;
   end Finalize;
end Terminal.App.Child_Tracker;
