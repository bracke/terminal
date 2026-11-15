separate (Terminal.App.Session_Table)
protected body Runtime_Borrow_Registry is
   procedure Register
     (Index : Terminal.App.Sessions.Session_Index;
      Item  : in out Runtime_Access) is
   begin
      if Item = null then
         raise Constraint_Error with "cannot register a null runtime";
      elsif Closing_All then
         raise Program_Error with "session table is closing";
      end if;
      for Slot of Entries loop
         if Slot.Closing then
            raise Program_Error with "a session runtime is closing";
         end if;
      end loop;
      if Entries (Index).Item /= null then
         raise Program_Error with "session runtime slot is already registered";
      end if;
      Entries (Index) := (Item => Item, Count => 0, Closing => False);
      Item := null;
   end Register;

   function Item_At
     (Index : Terminal.App.Sessions.Session_Index) return Runtime_Access is
     (Entries (Index).Item);

   procedure Acquire
     (Index   : Terminal.App.Sessions.Session_Index;
      Hold    : in out Runtime_Borrow_Hold) is
   begin
      Hold.Item := Entries (Index).Item;
      Hold.Active := False;
      if Hold.Item = null
        or else Closing_All
        or else Entries (Index).Closing
      then
         return;
      elsif Entries (Index).Count < Natural'Last then
         Entries (Index).Count := Entries (Index).Count + 1;
         Hold.Active := True;
      end if;
   end Acquire;

   procedure Release (Item : Runtime_Access) is
   begin
      if Item = null then
         return;
      end if;
      for I in Entries'Range loop
         if Entries (I).Item = Item then
            if Entries (I).Count = 0 then
               raise Program_Error with "runtime borrow count underflow";
            end if;
            Entries (I).Count := Entries (I).Count - 1;
            return;
         end if;
      end loop;
      raise Program_Error with "runtime borrow is not registered";
   end Release;

   procedure Begin_Remove
     (Index    : Terminal.App.Sessions.Session_Index;
      Item     : out Runtime_Access;
      Granted  : out Boolean;
      Retrying : out Boolean) is
   begin
      Item := Entries (Index).Item;
      Granted := False;
      Retrying := Entries (Index).Closing;
      if Item = null or else Closing_All then
         return;
      end if;
      for I in Entries'Range loop
         if I /= Index and then Entries (I).Closing then
            return;
         end if;
      end loop;
      if Entries (Index).Count = 0 then
         --  Closing remains set after teardown has started. Granting the same
         --  owner another exclusive attempt makes cleanup retryable.
         Entries (Index).Closing := True;
         Granted := True;
      end if;
   end Begin_Remove;

   procedure Cancel_Remove
     (Token : Terminal.App.Sessions.Session_Index) is
   begin
      if Entries (Token).Item = null or else not Entries (Token).Closing then
         raise Program_Error with "runtime removal is not reserved";
      end if;
      Entries (Token).Closing := False;
   end Cancel_Remove;

   procedure Move
     (From  : Terminal.App.Sessions.Session_Index;
      To    : Terminal.App.Sessions.Session_Index;
      Moved : out Boolean)
   is
      Saved : Runtime_Borrow_Entry;
   begin
      Moved := False;
      if Closing_All or else Entries (From).Item = null or else Entries (To).Item = null then
         return;
      end if;
      for Slot of Entries loop
         if Slot.Closing then
            return;
         end if;
      end loop;
      if From = To then
         Moved := True;
         return;
      end if;

      Saved := Entries (From);
      if From < To then
         for I in From .. To - 1 loop
            Entries (I) := Entries (I + 1);
         end loop;
      else
         for I in reverse To + 1 .. From loop
            Entries (I) := Entries (I - 1);
         end loop;
      end if;
      Entries (To) := Saved;
      Moved := True;
   end Move;

   procedure Complete_Remove
     (Token      : Terminal.App.Sessions.Session_Index;
      Shift_Left : Boolean;
      Item       : out Runtime_Access) is
   begin
      Item := null;
      if Entries (Token).Item = null
        or else not Entries (Token).Closing
        or else Entries (Token).Count /= 0
      then
         raise Program_Error with "runtime removal is not exclusive";
      end if;
      Item := Entries (Token).Item;
      Entries (Token) := (others => <>);
      if Shift_Left and then Token < Entries'Last then
         for I in Token .. Entries'Last - 1 loop
            Entries (I) := Entries (I + 1);
         end loop;
         Entries (Entries'Last) := (others => <>);
      end if;
   end Complete_Remove;

   procedure Begin_Close_All (Granted : out Boolean) is
   begin
      Granted := False;
      if Closing_All then
         --  A previous attempt may have closed only part of the table.
         Granted := True;
         return;
      end if;
      for Borrow_Entry of Entries loop
         if Borrow_Entry.Count /= 0 then
            return;
         end if;
      end loop;
      Closing_All := True;
      Granted := True;
   end Begin_Close_All;

   procedure Complete_Close_All (Items : out Runtime_Array) is
   begin
      Items := (others => null);
      if not Closing_All then
         raise Program_Error with "session table close is not reserved";
      end if;
      for I in Entries'Range loop
         if Entries (I).Count /= 0 then
            raise Program_Error with "session runtime is still borrowed";
         end if;
         Items (I) := Entries (I).Item;
         Entries (I) := (others => <>);
      end loop;
   end Complete_Close_All;

   procedure Finish_Close_All is
   begin
      if not Closing_All then
         raise Program_Error with "session table close is not reserved";
      end if;
      for Slot of Entries loop
         if Slot.Item /= null or else Slot.Count /= 0 then
            raise Program_Error with "session runtimes remain registered";
         end if;
      end loop;
      Closing_All := False;
   end Finish_Close_All;

   procedure Restore_Close_All (Items : in out Runtime_Array) is
   begin
      if not Closing_All then
         raise Program_Error with "session table close is not reserved";
      end if;
      for I in Entries'Range loop
         if Entries (I).Item /= null or else Entries (I).Count /= 0 then
            raise Program_Error with "session close restoration target is occupied";
         end if;
         Entries (I).Item := Items (I);
         Entries (I).Closing := Items (I) /= null;
         Items (I) := null;
      end loop;
   end Restore_Close_All;

   function Has_Items return Boolean is
   begin
      for Slot of Entries loop
         if Slot.Item /= null then
            return True;
         end if;
      end loop;
      return False;
   end Has_Items;

   function Is_Closing return Boolean is
   begin
      if Closing_All then
         return True;
      end if;
      for Slot of Entries loop
         if Slot.Closing then
            return True;
         end if;
      end loop;
      return False;
   end Is_Closing;
end Runtime_Borrow_Registry;
