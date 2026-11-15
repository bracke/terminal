separate (Terminal.App.Session_Table)
procedure Close_All_Internal
  (Table        : in out Runtime_Table;
   Raise_Errors : Boolean;
   Deallocate   : Runtime_Deallocator := null)
is
   First_Error : Ada.Exceptions.Exception_Occurrence;
   Failed      : Boolean := False;
   Have_Error  : Boolean := False;
   Reserved    : Boolean := False;
   Detached    : Runtime_Array := (others => null);
   Item        : Runtime_Access;

   procedure Quarantine (Value : in out Runtime_Access) is
   begin
      Retain_Deferred_Runtime (Value);
   end Quarantine;
begin
   Table.Borrows.Begin_Close_All (Reserved);
   if not Reserved then
      if Raise_Errors then
         raise Program_Error with "session runtimes are borrowed";
      end if;
      return;
   end if;
   --  Do not free individual slots until every runtime is closed.  On a
   --  partial failure Closing_All remains set, so cleanup can be retried
   --  but no caller can borrow a closed or half-closed runtime.
   for I in Runtime_Array'Range loop
      Item := Table.Borrows.Item_At (I);
      if Item /= null then
         begin
            Terminal.App.Session_Runtime.Close (Item.all);
            Failed := Failed or else
              Terminal.App.Session_Runtime.State (Item.all) /=
                Terminal.App.Session_Runtime.Closed;
         exception
            when Error : others =>
               if not Have_Error then
                  Ada.Exceptions.Save_Occurrence (First_Error, Error);
                  Have_Error := True;
               end if;
               Failed := True;
         end;
      end if;
   end loop;

   if Table.Pending_Start /= null then
      begin
         Release_Runtime (Table.Pending_Start);
      exception
         when Error : others =>
            if not Have_Error then
               Ada.Exceptions.Save_Occurrence (First_Error, Error);
               Have_Error := True;
            end if;
            Failed := True;
      end;
   end if;

   if Failed then
      --  Preserve the exclusive closing state.  Canceling it here would
      --  make successfully closed and Cleanup_Pending runtimes borrowable.
      if Raise_Errors then
         Reserved := False;
         if Have_Error then
            Ada.Exceptions.Reraise_Occurrence (First_Error);
         else
            raise Program_Error with
              "one or more session runtimes remain owned";
         end if;
      end if;

      --  Finalization has no future owner that could perform the normal
      --  retry.  Deallocating the retained startup runtime invokes Runtime's
      --  last-resort finalizer, which consumes its remaining resources.
      if Table.Pending_Start /= null then
         begin
            Free_Runtime (Table.Pending_Start);
         exception
            when Error : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Table,
                  Error,
                  "force release failed startup runtime");
               Quarantine (Table.Pending_Start);
         end;
      end if;
   end if;

   --  Remove every registry reference before freeing any designated
   --  runtime.  If deallocation unexpectedly fails, no future borrow can
   --  observe a pointer whose ownership has already been relinquished.
   Table.Borrows.Complete_Close_All (Detached);
   for I in Detached'Range loop
      if Detached (I) /= null then
         begin
            if Deallocate = null then
               Free_Runtime (Detached (I));
            else
               Deallocate.all (Detached (I));
            end if;
         exception
            when Error : others =>
               if Raise_Errors then
                  raise;
               end if;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Table,
                  Error,
                  "force release session runtime");
               Quarantine (Detached (I));
         end;
      end if;
   end loop;
   Terminal.App.Sessions.Clear (Table.Sessions);
   Terminal.App.Tabs.Clear (Table.Tabs);
   Terminal.App.Splits.Clear (Table.Splits);
   Table.Open := False;
   Table.Borrows.Finish_Close_All;
   Reserved := False;
exception
   when others =>
      --  Once Close_All has acquired exclusivity it is a one-way state
      --  transition.  Keeping Closing_All set is safer than exposing an
      --  entry after an unexpected teardown failure.
      if Reserved then
         Table.Borrows.Restore_Close_All (Detached);
         Reserved := False;
      end if;
      if Raise_Errors then
         raise;
      end if;
end Close_All_Internal;
