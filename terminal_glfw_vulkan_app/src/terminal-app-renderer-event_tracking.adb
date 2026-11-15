with Ada.Unchecked_Deallocation;
with Terminal.Common.Counters;

package body Terminal.App.Renderer.Event_Tracking is
   use type Staged_Graphics_Event_Access;
   use type String_Access;
   use type Terminal.Core.Graphics_Event_Sequence;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_Protocol_Kind;

   procedure Free_String is new Ada.Unchecked_Deallocation
     (String, String_Access);
   procedure Free_Staged_Graphics_Event is new Ada.Unchecked_Deallocation
     (Staged_Graphics_Event, Staged_Graphics_Event_Access);

   function Stage
     (R       : in out Renderer;
      Event   : Terminal.Core.Graphics_Event;
      Payload : String)
      return Terminal.App.Renderer.Event_Stage_Types.Status
   is
      use Terminal.App.Renderer.Event_Stage_Types;
      Existing : Staged_Graphics_Event_Access :=
        R.Graphics_State.Transaction.Staged_Events;
      Item : Staged_Graphics_Event_Access := null;
      Payload_Copy : String_Access := null;
   begin
      while Existing /= null loop
         exit when Existing.Stream_ID = Event.Stream_ID
           and then Existing.Sequence = Event.Sequence;
         Existing := Existing.Next;
      end loop;
      if Existing /= null then
         return Already_Stored;
      elsif R.Lifecycle.Closed or else not Event.Pending then
         return Not_Required;
      elsif Payload'Length /= Event.Payload_Length
        or else Payload'Length >
          Terminal.Common.Graphics_Limits.Max_Transaction_Bytes
      then
         return Invalid_Event;
      elsif R.Graphics_State.Transaction.Staged_Event_Count =
          Max_Staged_Graphics_Events
        or else Payload'Length >
          Max_Staged_Graphics_Bytes
            - R.Graphics_State.Transaction.Staged_Byte_Count
      then
         return Quota_Exceeded;
      elsif not Terminal.App.Image_Store.Allocation_Allowed
        (R.Graphics_State.Resources.Allocation_Control)
      then
         return Allocation_Failed;
      end if;

      --  The event tracker is the sole owner of both allocations and links
      --  the node only after its independently owned payload exists.
      Payload_Copy := new String'(Payload);
      if not Terminal.App.Image_Store.Allocation_Allowed
        (R.Graphics_State.Resources.Allocation_Control)
      then
         raise Storage_Error with "staged event node allocation rejected";
      end if;
      Item := new Staged_Graphics_Event'
        (Stream_ID => Event.Stream_ID,
         Sequence  => Event.Sequence,
         Payload   => Payload_Copy,
         Next      => R.Graphics_State.Transaction.Staged_Events);
      Payload_Copy := null;
      R.Graphics_State.Transaction.Staged_Events := Item;
      R.Graphics_State.Transaction.Staged_Event_Count :=
        R.Graphics_State.Transaction.Staged_Event_Count + 1;
      R.Graphics_State.Transaction.Staged_Byte_Count :=
        R.Graphics_State.Transaction.Staged_Byte_Count + Payload'Length;
      return Stored;
   exception
      when Storage_Error =>
         if Payload_Copy /= null then
            Free_String (Payload_Copy);
         end if;
         if Item /= null then
            if Item.Payload /= null then
               Free_String (Item.Payload);
            end if;
            Free_Staged_Graphics_Event (Item);
         end if;
         return Allocation_Failed;
   end Stage;

   procedure Release_Staged (Object : in out Renderer_Graphics_State) is
      Staged : Staged_Graphics_Event_Access :=
        Object.Transaction.Staged_Events;
   begin
      if Object.Transaction.Staged_Payload_Borrows /= 0 then
         raise Program_Error with
           "cannot release staged graphics payload while it is borrowed";
      end if;
      while Staged /= null loop
         declare
            Next : constant Staged_Graphics_Event_Access := Staged.Next;
         begin
            Free_String (Staged.Payload);
            Free_Staged_Graphics_Event (Staged);
            Staged := Next;
         end;
      end loop;
      Object.Transaction.Staged_Events := null;
      Object.Transaction.Staged_Event_Count := 0;
      Object.Transaction.Staged_Byte_Count := 0;
   end Release_Staged;

   procedure Release (Object : in out Renderer_Graphics_State) is
   begin
      Release_Staged (Object);
   end Release;
   function Find
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Staged_Graphics_Event_Access
   is
      Current : Staged_Graphics_Event_Access :=
        R.Graphics_State.Transaction.Staged_Events;
   begin
      while Current /= null loop
         if Current.Stream_ID = Event.Stream_ID
           and then Current.Sequence = Event.Sequence
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find;

   procedure With_Complete_Event_Text
     (R     : in out Renderer;
      Event : Terminal.Core.Graphics_Event;
      Process : not null access procedure (Text : String))
   is
      Staged : constant Staged_Graphics_Event_Access := Find (R, Event);
      procedure Invoke (Text : String) is
      begin
         R.Graphics_State.Transaction.Staged_Payload_Borrows :=
           R.Graphics_State.Transaction.Staged_Payload_Borrows + 1;
         begin
            Process (Text);
         exception
            when others =>
               R.Graphics_State.Transaction.Staged_Payload_Borrows :=
                 R.Graphics_State.Transaction.Staged_Payload_Borrows - 1;
               raise;
         end;
         R.Graphics_State.Transaction.Staged_Payload_Borrows :=
           R.Graphics_State.Transaction.Staged_Payload_Borrows - 1;
      end Invoke;
   begin
      if Staged /= null
        and then Staged.Payload /= null
        and then Staged.Payload'Length = Event.Payload_Length
      then
         Invoke (Staged.Payload.all);
      elsif Event.Preview_Length = Event.Payload_Length
        and then Event.Preview_Length = 0
      then
         Invoke ("");
      elsif Event.Preview_Length = Event.Payload_Length then
         Invoke (Event.Preview (1 .. Event.Preview_Length));
      else
         raise Program_Error with
           "complete graphics event payload was not staged";
      end if;
   end With_Complete_Event_Text;

   function Payload_Available
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean
   is
      Staged : constant Staged_Graphics_Event_Access := Find (R, Event);
   begin
      return not Event.Pending
        or else Event.Preview_Length = Event.Payload_Length
        or else
          (Staged /= null
           and then Staged.Payload /= null
           and then Staged.Payload'Length = Event.Payload_Length);
   end Payload_Available;

   function Already_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean is
   begin
      for I in 1 .. R.Graphics_State.Transaction.Processed_Event_Count loop
         if R.Graphics_State.Transaction.Processed_Events (I).Stream_ID =
              Event.Stream_ID
           and then R.Graphics_State.Transaction.Processed_Events (I).Sequence =
             Event.Sequence
         then
            return True;
         end if;
      end loop;
      return False;
   end Already_Processed;

   function Can_Remember
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean is
     (Already_Processed (R, Event)
      or else R.Graphics_State.Transaction.Processed_Event_Count <
        Max_Processed_Graphics_Events);

   procedure Remember
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Graphics_Completion) is
      use type Terminal.Core.Graphics_Completion_Code;
   begin
      for I in 1 .. R.Graphics_State.Transaction.Processed_Event_Count loop
         if R.Graphics_State.Transaction.Processed_Events (I).Stream_ID =
              Event.Stream_ID
           and then R.Graphics_State.Transaction.Processed_Events (I).Sequence =
             Event.Sequence
         then
            R.Graphics_State.Transaction.Processed_Events (I).Result := Result;
            return;
         end if;
      end loop;

      if R.Graphics_State.Transaction.Processed_Event_Count =
        Max_Processed_Graphics_Events
      then
         R.Graphics_State.Transaction.Event_Tracking_Failed := True;
         return;
      end if;
      R.Graphics_State.Transaction.Processed_Event_Count :=
        R.Graphics_State.Transaction.Processed_Event_Count + 1;
      R.Graphics_State.Transaction.Processed_Events
        (R.Graphics_State.Transaction.Processed_Event_Count) :=
          (Stream_ID => Event.Stream_ID,
           Sequence  => Event.Sequence,
           Result    => Result);
      if Event.Protocol = Terminal.Core.Kitty_Graphics then
         if Result.Code = Terminal.Core.Graphics_OK then
            Terminal.Common.Counters.Increment_Saturating
              (R.Graphics_State.Telemetry.Kitty_Success_Count);
         elsif Result.Code /= Terminal.Core.Graphics_No_Response then
            Terminal.Common.Counters.Increment_Saturating
              (R.Graphics_State.Telemetry.Kitty_Error_Count);
         end if;
      end if;
   end Remember;

   procedure Clear (R : in out Renderer) is
   begin
      if R.Graphics_State.Transaction.Staged_Payload_Borrows /= 0 then
         raise Program_Error with
           "cannot clear graphics events while a payload is borrowed";
      end if;
      R.Graphics_State.Transaction.Processed_Events :=
        (others => (others => <>));
      R.Graphics_State.Transaction.Processed_Event_Count := 0;
      R.Graphics_State.Transaction.Event_Tracking_Failed := False;
      Release_Staged (R.Graphics_State);
   end Clear;

   procedure Remove
     (R              : in out Renderer;
      Stream_ID      : Terminal.Core.Graphics_Stream_ID;
      Sequence       : Terminal.Core.Graphics_Event_Sequence;
      Match_Sequence : Boolean)
   is
      Kept : Natural := 0;
      Previous : Staged_Graphics_Event_Access := null;
      Current : Staged_Graphics_Event_Access :=
        R.Graphics_State.Transaction.Staged_Events;
   begin
      if R.Graphics_State.Transaction.Staged_Payload_Borrows /= 0 then
         raise Program_Error with
           "cannot remove staged graphics payload while it is borrowed";
      end if;
      for I in 1 .. R.Graphics_State.Transaction.Processed_Event_Count loop
         if R.Graphics_State.Transaction.Processed_Events (I).Stream_ID /=
              Stream_ID
           or else
             (Match_Sequence
              and then
                R.Graphics_State.Transaction.Processed_Events (I).Sequence /=
                  Sequence)
         then
            Kept := Kept + 1;
            if Kept /= I then
               R.Graphics_State.Transaction.Processed_Events (Kept) :=
                 R.Graphics_State.Transaction.Processed_Events (I);
            end if;
         end if;
      end loop;
      for I in Kept + 1 ..
        R.Graphics_State.Transaction.Processed_Event_Count
      loop
         R.Graphics_State.Transaction.Processed_Events (I) := (others => <>);
      end loop;
      R.Graphics_State.Transaction.Processed_Event_Count := Kept;

      while Current /= null loop
         declare
            Next : constant Staged_Graphics_Event_Access := Current.Next;
         begin
            if Current.Stream_ID = Stream_ID
              and then
                (not Match_Sequence or else Current.Sequence = Sequence)
            then
               if Previous = null then
                  R.Graphics_State.Transaction.Staged_Events := Next;
               else
                  Previous.Next := Next;
               end if;
               R.Graphics_State.Transaction.Staged_Event_Count :=
                 R.Graphics_State.Transaction.Staged_Event_Count - 1;
               if Current.Payload /= null then
                  R.Graphics_State.Transaction.Staged_Byte_Count :=
                    R.Graphics_State.Transaction.Staged_Byte_Count
                      - Current.Payload'Length;
                  Free_String (Current.Payload);
               end if;
               Free_Staged_Graphics_Event (Current);
               exit when Match_Sequence;
            else
               Previous := Current;
            end if;
            Current := Next;
         end;
      end loop;
   end Remove;
end Terminal.App.Renderer.Event_Tracking;
