with Terminal.Core.Graphics_Runtime;

separate (Terminal.Core)
procedure Complete_Graphics_Event
  (T      : in out Terminal;
   Event  : Graphics_Event;
   Result : Graphics_Completion)
is
   Node : constant Graphics_Event_Node_Access := T.Graphics.Head;
   Was_Blocking : Boolean := False;
   Was_Blocked : Boolean := False;

   function Message return String is
   begin
      case Result.Code is
         when Graphics_No_Response => return "";
         when Graphics_OK          => return "OK";
         when Graphics_EINVAL      => return "EINVAL:Invalid control data";
         when Graphics_ENOENT      => return "ENOENT:Image or placement not found";
         when Graphics_ENOMEM      => return "ENOMEM:Image resource limit exceeded";
         when Graphics_ENOSPC      => return "ENOSPC:Graphics resource limit exceeded";
         when Graphics_EBADF       => return "EBADF:Failed to read image file";
         when Graphics_ENOTSUP     => return "ENOTSUP:Unsupported graphics operation";
         when Graphics_ENOPARENT   => return "ENOPARENT:Parent placement not found";
         when Graphics_ECYCLE      => return "ECYCLE:Relative placement cycle";
         when Graphics_ETOODEEP    => return "ETOODEEP:Relative placement chain too deep";
      end case;
   end Message;
begin
   if Node = null
     or else not Event.Pending
     or else Event.Protocol /= Node.Protocol
     or else Event.Stream_ID /= Node.Stream_ID
     or else Event.Sequence /= Node.Sequence
   then
      return;
   end if;

   Was_Blocking := Node.Blocks_Input;
   Was_Blocked := T.Graphics.Input_Blocked;

   if Node.Protocol = Kitty_Graphics
     and then Result.Kitty_Response.Present
     and then Result.Code /= Graphics_No_Response
     and then Result.Kitty_Response.Respond
     and then Result.Kitty_Response.Quiet /= 2
     and then not
       (Result.Code = Graphics_OK and then Result.Kitty_Response.Quiet = 1)
   then
      Begin_Response (T);
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_String (T, "_Gi=");
      Append_Response_Graphics_ID (T, Result.Kitty_Response.Image_ID);
      if Result.Kitty_Response.Has_Image_Number then
         Append_Response_String (T, ",I=");
         Append_Response_Graphics_ID (T, Result.Kitty_Response.Image_Number);
      end if;
      if Result.Kitty_Response.Has_Placement_ID then
         Append_Response_String (T, ",p=");
         Append_Response_Graphics_ID (T, Result.Kitty_Response.Placement_ID);
      end if;
      Append_Response_Char (T, ';');
      Append_Response_String (T, Message);
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_Char (T, '\');
      End_Response (T);
   end if;

   if Was_Blocking
     and then Result.Code = Graphics_OK
     and then Result.Cursor.Move
   then
      declare
         Target_Col : Positive;
         Anchor_Row : constant Positive := Positive'Min (Event.Row, T.Rows);
         Anchor_Col : constant Positive := Positive'Min (Event.Col, T.Cols);
         Old_Row    : constant Positive := T.Cursor_Row;
         Vertical_Steps : Positive := Result.Cursor.Placement_Rows;
         Scroll_Budget : constant Positive :=
           (if Node.Protocol = Kitty_Graphics
            then 1 else Max_Graphics_Scroll_Events);
      begin
         --  Kitty defines movement beyond the screen or scroll area as
         --  implementation-dependent.  Stop after the first boundary scroll
         --  rather than replaying an untrusted placement height.  Bound other
         --  protocols by the scroll journal capacity so every generated
         --  scroll remains observable by the renderer.
         if Anchor_Row <= T.Bottom_Margin then
            declare
               Steps_To_Margin : constant Natural :=
                 T.Bottom_Margin - Anchor_Row;
               Maximum_Steps : constant Positive :=
                 (if Steps_To_Margin > Positive'Last - Scroll_Budget
                  then Positive'Last
                  else Steps_To_Margin + Scroll_Budget);
            begin
               Vertical_Steps :=
                 Positive'Min (Vertical_Steps, Maximum_Steps);
            end;
         else
            Vertical_Steps :=
              Positive'Min (Vertical_Steps, T.Rows - Anchor_Row + 1);
         end if;
         T.Cursor_Row := Anchor_Row;
         for Row in 1 .. Vertical_Steps loop
            New_Line (T);
         end loop;
         if Result.Cursor.To_Line_Start then
            Target_Col := 1;
         elsif Result.Cursor.Placement_Columns > T.Cols - Anchor_Col then
            Target_Col := T.Cols;
         else
            Target_Col := Anchor_Col + Result.Cursor.Placement_Columns;
         end if;
         T.Cursor_Col := Target_Col;
         T.Pending_Wrap := False;
         Mark_Cursor_Move (T, Old_Row);
      end;
   end if;

   Graphics_Runtime.Drop_Graphics_Head (T.Graphics);
   if Was_Blocked and then not T.Graphics.Input_Blocked then
      Graphics_Events.Resume_Deferred_Input (T);
   end if;
exception
   when others =>
      Response_Facade.Abort_Transaction (T);
      raise;
end Complete_Graphics_Event;
