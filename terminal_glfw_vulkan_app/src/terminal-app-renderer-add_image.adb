separate (Terminal.App.Renderer)
procedure Add_Image
  (R      : in out Renderer;
   Event  : Terminal.Core.Graphics_Event;
   Snapshot : Terminal.Core.Render_Snapshot)
is
   Event_Header : constant Terminal.App.Graphics.Graphics_Header :=
     Terminal.App.Graphics.Header (Event);
   Header : Terminal.App.Graphics.Graphics_Header := Event_Header;
   Result : Terminal.Core.Graphics_Completion := (others => <>);
   Number_Object_Before : Image_Object_Access := null;
   Resolved_ID : Terminal.Core.Graphics_ID := 0;
   Placement_Image_ID : Terminal.Core.Graphics_ID := 0;
   Resolved_Geometry : Placement_Geometry := (others => <>);
   Geometry_Checked : Boolean := False;
   Placement_Status : Placement_Store_Status := Placement_Not_Requested;
   Image_Count_Before : constant Natural := Image_Commands.Count (R);
   Placement_Count_Before : constant Natural := Placements_State.Stored_Placement_Count (R);
   Validation_Error : constant Boolean :=
     Event.Cancelled and then Event.Payload_Length > 0;
   Invalid_Chunk_Transition : constant Boolean :=
     Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Event_Header.Recognized
     and then
       (not Event_Header.Kitty_More_Valid
        or else Event_Header.Kitty_More
        or else
          (Event_Header.Kitty_Transmission in 'f' | 't' | 's'
           and then Event_Header.Kitty_More_Specified));
   Retry_Sensitive : constant Boolean :=
     Event.Pending
     and then Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Event.Sequence /= 0
     and then
       (Event_Header.Recognized
        and then
          (Event_Header.Kitty_More
           or else Event_Header.Kitty_More_Specified
           or else Event_Header.Kitty_ID /= 0
           or else Event_Header.Kitty_Image_Number /= 0
           or else Event_Header.Kitty_Action = 'd'));
   Replay_Guarded : constant Boolean :=
     Retry_Sensitive
     or else
       (Event.Pending
        and then Event.Sequence /= 0
        and then Event.Protocol in
          Terminal.Core.Sixel_Graphics | Terminal.Core.ITerm2_Graphics);
   Track_Result : constant Boolean :=
     Retry_Sensitive
     or else
       (Event.Pending
        and then Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Event.Sequence /= 0
        and then Event_Header.Recognized
        and then not Event_Header.Kitty_More
        and then Event_Header.Kitty_Action in 'T' | 'p' | 'q');


   function Placement_Exists
     (Image_ID : Terminal.Core.Graphics_ID) return Boolean
   is
   begin
      if Image_ID = 0 then
         if R.Graphics_State.Transaction.Last_Stored_Image_Order /= 0 then
            return Placements_State.Has_Conventional_Storage_Order
              (R,
               Event.Stream_ID,
               R.Graphics_State.Transaction.Last_Stored_Image_Order);
         end if;
         return Image_Commands.Count (R) > Image_Count_Before;
      elsif Header.Kitty_Virtual_Placement then
         if Header.Kitty_Placement_ID = 0 then
            --  Implicit placements are deliberately not addressable.
            --  A plain placement command must increase the count.  A
            --  transmit-and-display replacement may first remove the old
            --  image's placement, so identify its newly stored object by
            --  storage order in that case.
            if Placements_State.Stored_Placement_Count (R) > Placement_Count_Before then
               return True;
            elsif Header.Kitty_Action /= 'T' then
               return False;
            end if;
            return Placements_State.Has_Implicit_Virtual
              (R,
               Event.Stream_ID,
               Event.Alternate_Screen,
               Event.Screen_Generation,
               Image_ID,
               R.Graphics_State.Transaction.Last_Stored_Image_Order);
         end if;
         return Placements_State.Find_Virtual_Placement
           (R,
            Event.Stream_ID,
            Event.Alternate_Screen,
            Event.Screen_Generation,
            Image_ID,
            Header.Kitty_Placement_ID).Exists;
      elsif Header.Kitty_Placement_ID /= 0 then
         return Placements_State.Find_Conventional_Placement
           (R,
            Event.Stream_ID,
            Event.Alternate_Screen,
            Event.Screen_Generation,
            Image_ID,
            Header.Kitty_Placement_ID).Exists;
      end if;

      --  As with virtual prototypes, a conventional p=0 placement is a
      --  new, non-addressable object for each command.  A replacement can
      --  leave the total count unchanged after removing the old image;
      --  its storage order distinguishes the replacement from stale data.
      if Placements_State.Stored_Placement_Count (R) > Placement_Count_Before then
         return True;
      elsif Header.Kitty_Action /= 'T' then
         return False;
      end if;
      return Placements_State.Has_Implicit_Conventional
        (R,
         Event.Stream_ID,
         Event.Alternate_Screen,
         Event.Screen_Generation,
         Image_ID,
         R.Graphics_State.Transaction.Last_Stored_Image_Order);
   end Placement_Exists;

   function Validate_Kitty_Command
     return Terminal.Core.Graphics_Completion_Code
   is
   begin
      if Event.Protocol /= Terminal.Core.Kitty_Graphics
        or else not Header.Recognized
      then
         return Terminal.Core.Graphics_No_Response;
      elsif Header.Kitty_ID > 0 and then Header.Kitty_Image_Number > 0 then
         return Terminal.Core.Graphics_EINVAL;
      elsif Header.Kitty_Action not in 't' | 'T' | 'p' | 'd' | 'f' | 'a' | 'c'
        or else not Header.Kitty_Transmission_Valid
        or else not Header.Kitty_Compression_Valid
      then
         return Terminal.Core.Graphics_ENOTSUP;
      elsif not Header.Kitty_Control_Data_Valid
        or else not Header.Kitty_Action_Controls_Valid
        or else
          (Header.Kitty_Transmission in 'f' | 't' | 's'
           and then
             (not Header.Kitty_Data_Size_Valid
              or else not Header.Kitty_Data_Offset_Valid
              or else Header.Kitty_More_Specified))
      then
         return Terminal.Core.Graphics_EINVAL;
      else
         return Terminal.Core.Graphics_OK;
      end if;
   end Validate_Kitty_Command;

   procedure Finalize_Response is separate;
begin
   if Event.Cancelled and then not Validation_Error then
      if Event.Protocol = Terminal.Core.ITerm2_Graphics then
         Clear_Last_Media_Diagnostics (R);
      end if;
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Graphics_Event_Count);
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Kitty_Command_Count);
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Chunk_Cancel_Count);
      return;
   end if;

   if Replay_Guarded
     and then Graphics_Event_Already_Processed (R, Event)
   then
      return;
   end if;

   --  The result cache is fixed-capacity and covers every pane in an app
   --  frame. Refuse unsupported oversized snapshot batches before applying
   --  any persistent graphics side effect.
   if (Replay_Guarded or else Track_Result)
     and then not Can_Remember_Graphics_Event (R, Event)
   then
      R.Graphics_State.Transaction.Event_Tracking_Failed := True;
      return;
   end if;

   if Event.Protocol = Terminal.Core.ITerm2_Graphics then
      --  Diagnostics describe the current event, including malformed and
      --  non-inline commands that never enter a decoder. Do this only after
      --  replay detection so a presentation retry retains its result.
      Clear_Last_Media_Diagnostics (R);
   end if;

   Terminal.Common.Counters.Increment_Saturating
     (R.Graphics_State.Telemetry.Graphics_Event_Count);
   if Event.Protocol = Terminal.Core.Kitty_Graphics then
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Kitty_Command_Count);
   end if;

   if Track_Result and then Header.Recognized then
      Result :=
        Terminal.App.Graphics.Kitty_Result_From_Header
          (Header, Result.Code);

      if Header.Kitty_Image_Number /= 0 then
         Number_Object_Before :=
           Image_Objects.Find_By_Number
             (R, Event.Stream_ID, Header.Kitty_Image_Number);
      end if;
      if Header.Kitty_ID /= 0 then
         Resolved_ID := Header.Kitty_ID;
      elsif Header.Kitty_Image_Number /= 0
        and then Header.Kitty_Action not in 't' | 'T'
        and then Number_Object_Before /= null
      then
         Resolved_ID := Number_Object_Before.ID;
      end if;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Validation_Error
   then
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Chunk_Cancel_Count);
      Image_Commands.Truncate (R, Image_Count_Before);
      if Track_Result and then Header.Recognized then
         Result.Code := Terminal.Core.Graphics_EINVAL;
         Remember_Processed_Graphics_Event (R, Event, Result);
      end if;
      return;
   end if;

   if Invalid_Chunk_Transition then
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Chunk_Cancel_Count);
      Image_Commands.Truncate (R, Image_Count_Before);
      if Track_Result then
         Result.Code := Terminal.Core.Graphics_EINVAL;
         Remember_Processed_Graphics_Event (R, Event, Result);
      end if;
      return;
   end if;

   if Track_Result
     and then Header.Recognized
     and then Header.Kitty_Action = 'q'
   then
      Result.Kitty_Response.Image_ID := Header.Kitty_ID;
      if Header.Kitty_ID = 0
        or else Header.Kitty_Image_Number /= 0
        or else not Header.Kitty_More_Valid
      then
         Result.Code := Terminal.Core.Graphics_EINVAL;
      elsif not Header.Kitty_Transmission_Valid
        or else not Header.Kitty_Compression_Valid
        or else Header.Kitty_Format not in 8 | 16 | 24 | 32 | 100
          | Terminal.App.Graphics.Kitty_JPEG_Format | Terminal.App.Graphics.Kitty_GIF_Format
      then
         Result.Code := Terminal.Core.Graphics_ENOTSUP;
      elsif not Header.Kitty_Control_Data_Valid
        or else not Header.Kitty_Action_Controls_Valid
      then
         Result.Code := Terminal.Core.Graphics_EINVAL;
      else
         declare
            Query_Header : Terminal.App.Graphics.Graphics_Header := Header;
            procedure Validate_Query (Text : String) is
            begin
               Result.Code :=
                 Terminal.App.Image_Ingestion.Validate_Kitty_Query
                   (Query_Header,
                    Text,
                    R.Graphics_State.Policy.Access_Policy,
                    R.Graphics_State.Policy.Limits.Per_Image_Bytes,
                    R.Graphics_State.Policy.Limits.Pixel_Dimension,
                    R.Graphics_State.Policy.Limits.Animation_Frames);
            end Validate_Query;
         begin
            if Query_Header.Kitty_Format = 0 then
               Query_Header.Kitty_Format := 32;
               Query_Header.Raw_Format := 32;
            end if;
            Event_Tracking.With_Complete_Event_Text
              (R, Event, Validate_Query'Access);
         end;
      end if;
      Remember_Processed_Graphics_Event (R, Event, Result);
      return;
   end if;

   declare
      Validation : constant Terminal.Core.Graphics_Completion_Code :=
        Validate_Kitty_Command;
   begin
   if Validation not in
     Terminal.Core.Graphics_OK | Terminal.Core.Graphics_No_Response
   then
      if Track_Result then
         Result.Code := Validation;
         Remember_Processed_Graphics_Event (R, Event, Result);
      end if;
      return;
   end if;
   end;

   if Event.Protocol = Terminal.Core.ITerm2_Graphics
     and then Header.Recognized
     and then Header.ITerm2_Control_Data_Valid
     and then not Header.ITerm2_Inline
   then
      declare
         Save_Status : Terminal.App.ITerm2_Files.Save_Status;
         Saved_Name : String
           (1 .. Terminal.App.ITerm2_Files.Max_File_Name_Length);
         Saved_Length : Natural;
         procedure Save_Download (Text : String) is
         begin
            Terminal.App.ITerm2_Files.Save
              (Text,
               R.Graphics_State.Policy.ITerm2_Downloads,
               R.Graphics_State.Policy.Limits.Per_Image_Bytes,
               Save_Status,
               Saved_Name,
               Saved_Length);
         end Save_Download;
      begin
         Event_Tracking.With_Complete_Event_Text
           (R, Event, Save_Download'Access);
         pragma Unreferenced (Saved_Name, Saved_Length);
         Result.Code :=
           (case Save_Status is
              when Terminal.App.ITerm2_Files.Save_Ok =>
                Terminal.Core.Graphics_OK,
              when Terminal.App.ITerm2_Files.Save_Too_Large =>
                Terminal.Core.Graphics_ENOSPC,
              when Terminal.App.ITerm2_Files.Save_Allocation_Failed =>
                Terminal.Core.Graphics_ENOMEM,
              when Terminal.App.ITerm2_Files.Save_Disabled =>
                Terminal.Core.Graphics_ENOTSUP,
              when Terminal.App.ITerm2_Files.Save_Invalid_Command
                 | Terminal.App.ITerm2_Files.Save_Invalid_Name
                 | Terminal.App.ITerm2_Files.Save_Invalid_Data =>
                Terminal.Core.Graphics_EINVAL,
              when others => Terminal.Core.Graphics_EBADF);
         if Save_Status =
           Terminal.App.ITerm2_Files.Save_Allocation_Failed
         then
            Terminal.Common.Counters.Increment_Saturating
              (R.Graphics_State.Telemetry.Allocation_Failure_Count);
         elsif Save_Status /= Terminal.App.ITerm2_Files.Save_Ok then
            Terminal.Common.Counters.Increment_Saturating
              (R.Graphics_State.Telemetry.Transport_Failure_Count);
         end if;
         Remember_Processed_Graphics_Event (R, Event, Result);
         return;
      end;
   end if;

   R.Graphics_State.Transaction.Image_Store_Allocation_Failed := False;
   R.Graphics_State.Transaction.Image_Transport_Failed := False;
   R.Graphics_State.Transaction.Last_Animation_Result := Terminal.Core.Graphics_No_Response;
   Apply_Image_Event (R, Event, Snapshot, Placement_Status);
   if Placements_State.Stored_Placement_Count (R) > Placement_Count_Before then
      Terminal.Common.Counters.Add_Saturating
        (R.Graphics_State.Telemetry.Placement_Create_Count,
         Interfaces.Unsigned_64
           (Placements_State.Stored_Placement_Count (R)
            - Placement_Count_Before));
   elsif Placements_State.Stored_Placement_Count (R) < Placement_Count_Before then
      Terminal.Common.Counters.Add_Saturating
        (R.Graphics_State.Telemetry.Placement_Delete_Count,
         Interfaces.Unsigned_64
           (Placement_Count_Before
            - Placements_State.Stored_Placement_Count (R)));
   end if;
   if R.Graphics_State.Transaction.Image_Transport_Failed then
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Transport_Failure_Count);
   end if;
   if R.Graphics_State.Transaction.Image_Store_Allocation_Failed then
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Allocation_Failure_Count);
   end if;
   if Event.Protocol = Terminal.Core.ITerm2_Graphics
     and then Header.Recognized
     and then Header.ITerm2_Control_Data_Valid
     and then Header.ITerm2_Inline
   then
      declare
         Position : Placements_State.Conventional_Cursor :=
           Placements_State.First_Conventional (R);
         Placement : Conventional_Placement_State;
         Found : Boolean := False;
      begin
         while Placements_State.Has_Element (Position) loop
            Placement := Placements_State.Element (Position);
            Found := Placement.Stream_ID = Event.Stream_ID
              and then Placement.Protocol = RM.Image_ITerm2
              and then Placement.Image_Storage_Order =
                R.Graphics_State.Transaction.Last_Stored_Image_Order;
            exit when Found;
            Placements_State.Advance (Position);
            Placement := (others => <>);
         end loop;
         if Found
           and then R.Graphics_State.Transaction.Last_Stored_Image_Order /= 0
         then
            --  iTerm2 emits no protocol reply, but an internal success
            --  result commits its default cursor movement atomically with
            --  the decoded image. Complete_Graphics_Event serializes
            --  replies only for Kitty events.
            Result.Code := Terminal.Core.Graphics_OK;
            if not Header.ITerm2_Do_Not_Move_Cursor then
               Result.Cursor.Move := True;
               Result.Cursor.To_Line_Start := True;
               Result.Cursor.Placement_Columns := 1;
               Result.Cursor.Placement_Rows := Placement.Rows;
            end if;
         end if;
      end;
   end if;
   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action in 'T' | 'p'
   then
      Placement_Image_ID := Header.Kitty_ID;
      if Placement_Image_ID = 0
        and then Header.Kitty_Image_Number /= 0
      then
         declare
            Stored : constant Image_Object_Access :=
              Image_Objects.Find_By_Number
                (R, Event.Stream_ID, Header.Kitty_Image_Number);
         begin
            if Stored /= null then
               Placement_Image_ID := Stored.ID;
            end if;
         end;
      end if;
      if Placement_Image_ID /= 0 then
         declare
            Object : constant Image_Object_Access :=
              Image_Objects.Find
                (R, Event.Stream_ID, Placement_Image_ID);
         begin
            if Object /= null then
               Resolved_Geometry :=
                 Placements_State.Resolve_Placement_Geometry (R, Object, Header);
               Geometry_Checked := True;
            end if;
         end;
      elsif Header.Kitty_Action = 'T'
        and then R.Graphics_State.Transaction.Last_Stored_Image_Order /= 0
      then
         declare
            Object : constant Image_Object_Access :=
              Image_Objects.Find_By_Storage_Order
                (R, Event.Stream_ID, R.Graphics_State.Transaction.Last_Stored_Image_Order);
         begin
            if Object /= null then
               Resolved_Geometry :=
                 Placements_State.Resolve_Placement_Geometry (R, Object, Header);
               Geometry_Checked := True;
            end if;
         end;
      elsif Header.Kitty_Action = 'T'
        and then Image_Commands.Commands (R) /= null
        and then Image_Commands.Count (R) > Image_Count_Before
      then
         Resolved_Geometry :=
           Placements_State.Resolve_Placement_Geometry
             (R,
              FIS.Element (R.Frame_State.Frame_Images, Image_Commands.Count (R)).Pixel_Width,
              FIS.Element (R.Frame_State.Frame_Images, Image_Commands.Count (R)).Pixel_Height,
              Header);
         Geometry_Checked := True;
      end if;
   end if;
   Finalize_Response;
end Add_Image;
