separate (Terminal.Core)
procedure Complete_Graphics_Event
  (T      : in out Terminal;
   Event  : Graphics_Event;
   Result : Kitty_Graphics_Result)
is
   Node : constant Graphics_Event_Node_Access := T.Graphics_Head;
   Was_Blocking : Boolean := False;
   Was_Blocked : Boolean := False;

   function Message return String is
   begin
      case Result.Code is
         when Kitty_No_Response => return "";
         when Kitty_OK          => return "OK";
         when Kitty_EINVAL      => return "EINVAL:Invalid control data";
         when Kitty_ENOENT      => return "ENOENT:Image or placement not found";
         when Kitty_ENOMEM      => return "ENOMEM:Image resource limit exceeded";
         when Kitty_ENOSPC      => return "ENOSPC:Insufficient animation storage";
         when Kitty_EBADF       => return "EBADF:Failed to read image file";
         when Kitty_ENOTSUP     => return "ENOTSUP:Unsupported graphics operation";
         when Kitty_ENOPARENT   => return "ENOPARENT:Parent placement not found";
         when Kitty_ECYCLE      => return "ECYCLE:Relative placement cycle";
         when Kitty_ETOODEEP    => return "ETOODEEP:Relative placement chain too deep";
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
   Was_Blocked := T.Graphics_Input_Blocked;

   if Node.Protocol = Kitty_Graphics
     and then Result.Code /= Kitty_No_Response
     and then Result.Respond
     and then Result.Quiet /= 2
     and then not (Result.Code = Kitty_OK and then Result.Quiet = 1)
   then
      Begin_Response (T);
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_String (T, "_Gi=");
      Append_Response_Graphics_ID (T, Result.Image_ID);
      if Result.Has_Image_Number then
         Append_Response_String (T, ",I=");
         Append_Response_Graphics_ID (T, Result.Image_Number);
      end if;
      if Result.Has_Placement_ID then
         Append_Response_String (T, ",p=");
         Append_Response_Graphics_ID (T, Result.Placement_ID);
      end if;
      Append_Response_Char (T, ';');
      Append_Response_String (T, Message);
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_Char (T, '\');
      End_Response (T);
   end if;

   if Was_Blocking
     and then Result.Code = Kitty_OK
     and then Result.Move_Cursor
   then
      declare
         Target_Row : Positive;
         Target_Col : Positive;
      begin
         if Result.Placement_Rows > T.Rows - Event.Row then
            Target_Row := T.Rows;
         else
            Target_Row := Event.Row + Result.Placement_Rows;
         end if;
         if Result.Cursor_To_Line_Start then
            Target_Col := 1;
         elsif Result.Placement_Columns > T.Cols - Event.Col then
            Target_Col := T.Cols;
         else
            Target_Col := Event.Col + Result.Placement_Columns;
         end if;
         declare
            Old_Row : constant Positive := T.Cursor_Row;
         begin
            T.Cursor_Row := Target_Row;
            T.Cursor_Col := Target_Col;
            T.Pending_Wrap := False;
            Mark_Cursor_Move (T, Old_Row);
         end;
      end;
   end if;

   Drop_Graphics_Head (T);
   Refresh_Graphics_Input_Block (T);
   if Was_Blocked and then not T.Graphics_Input_Blocked then
      Resume_Deferred_Input (T);
   end if;
end Complete_Graphics_Event;
