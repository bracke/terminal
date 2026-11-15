separate (Terminal.Core)
procedure Handle_DECRQSS (T : in out Terminal) is
   function Cursor_Style_Param return Natural is
   begin
      case T.Current_Cursor_Shape is
         when Cursor_Block =>
            return (if T.Current_Cursor_Blinking then 1 else 2);
         when Cursor_Underline =>
            return (if T.Current_Cursor_Blinking then 3 else 4);
         when Cursor_Bar =>
            return (if T.Current_Cursor_Blinking then 5 else 6);
      end case;
   end Cursor_Style_Param;
begin
   Begin_Response (T);
   if T.Parser.Ignored_String_Count = 2 then
      Append_DECRQSS_Negative (T);
   elsif T.Parser.Ignored_String_Count = 4
     and then T.Parser.Ignored_String_Data (3) = ' '
     and then T.Parser.Ignored_String_Data (4) = 'q'
   then
      Append_DECRQSS_Start (T, Valid => True);
      Append_Response_Natural (T, Cursor_Style_Param);
      Append_Response_Char (T, ' ');
      Append_Response_Char (T, 'q');
      Append_DECRQSS_End (T);
   else
      case T.Parser.Ignored_String_Data (3) is
         when 'm' =>
            if T.Parser.Ignored_String_Count = 3 then
               Append_DECRQSS_Start (T, Valid => True);
               Append_SGR_Status (T);
               Append_DECRQSS_End (T);
            else
               Append_DECRQSS_Negative (T);
            end if;
         when 'r' =>
            if T.Parser.Ignored_String_Count = 3 then
               Append_DECRQSS_Start (T, Valid => True);
               Append_Response_Natural (T, T.Top_Margin);
               Append_Response_Char (T, ';');
               Append_Response_Natural (T, T.Bottom_Margin);
               Append_Response_Char (T, 'r');
               Append_DECRQSS_End (T);
            else
               Append_DECRQSS_Negative (T);
            end if;
         when others =>
            Append_DECRQSS_Negative (T);
      end case;
   end if;
   End_Response (T);
end Handle_DECRQSS;
