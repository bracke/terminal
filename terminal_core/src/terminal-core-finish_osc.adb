separate (Terminal.Core)
procedure Finish_OSC (T : in out Terminal) is
   Command : Natural := 0;
   Payload_First : Natural := 0;
   Title_Length : Natural;

   function Payload_Starts_With (Text : String) return Boolean is
   begin
      if Payload_First = 0
        or else T.OSC_Count - Payload_First + 1 < Text'Length
      then
         return False;
      end if;

      for I in Text'Range loop
         if T.OSC_Data (Payload_First + I - Text'First) /= Text (I) then
            return False;
         end if;
      end loop;
      return True;
   end Payload_Starts_With;

   function Base64_Value (Ch : Standard.Character) return Integer is
   begin
      case Ch is
         when 'A' .. 'Z' =>
            return Standard.Character'Pos (Ch) - Standard.Character'Pos ('A');
         when 'a' .. 'z' =>
            return 26 + Standard.Character'Pos (Ch) - Standard.Character'Pos ('a');
         when '0' .. '9' =>
            return 52 + Standard.Character'Pos (Ch) - Standard.Character'Pos ('0');
         when '+' =>
            return 62;
         when '/' =>
            return 63;
         when others =>
            return -1;
      end case;
   end Base64_Value;

   procedure Decode_OSC52
     (First : Natural;
      Last  : Natural)
   is
      Enc_First : Natural := 0;
      Out_Len   : Natural := 0;
      Bits      : Natural := 0;
      Bit_Count : Natural := 0;
      Invalid   : Boolean := False;
      Done      : Boolean := False;
      Target    : Clipboard_Target := Clipboard_Clipboard;

      function Parse_Target return Boolean is
         Saw_Supported : Boolean := False;
      begin
         if Enc_First <= First + 1 then
            return True;
         end if;

         for I in First .. Enc_First - 2 loop
            case T.OSC_Data (I) is
               when 'c' =>
                  Target := Clipboard_Clipboard;
                  Saw_Supported := True;
               when 'p' =>
                  if not Saw_Supported then
                     Target := Clipboard_Primary;
                  end if;
                  Saw_Supported := True;
               when 's' =>
                  if not Saw_Supported then
                     Target := Clipboard_Selection;
                  end if;
                  Saw_Supported := True;
               when others =>
                  return False;
            end case;
         end loop;

         return Saw_Supported;
      end Parse_Target;

      procedure Append_Decoded (Value : Natural) is
      begin
         if Out_Len >= Max_Clipboard_Length then
            T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
            Invalid := True;
         else
            Out_Len := Out_Len + 1;
            T.Clipboard_Data.Text (Out_Len) :=
              Standard.Character'Val (Value);
         end if;
      end Append_Decoded;
   begin
      for I in First .. Last loop
         if T.OSC_Data (I) = ';' then
            Enc_First := I + 1;
            exit;
         end if;
      end loop;

      if Enc_First = 0 then
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         return;
      end if;

      T.Clipboard_Data := (others => <>);
      if not Parse_Target then
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         return;
      end if;

      if Enc_First = Last and then T.OSC_Data (Enc_First) = '?' then
         T.Clipboard_Data.Pending := True;
         T.Clipboard_Data.Operation := Clipboard_Query;
         T.Clipboard_Data.Target := Target;
         return;
      end if;

      if Enc_First <= Last then
         for I in Enc_First .. Last loop
            declare
               Ch : constant Standard.Character := T.OSC_Data (I);
               V  : constant Integer := Base64_Value (Ch);
            begin
               if Ch = '=' then
                  Done := True;
               elsif Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
                  null;
               elsif Done or else V < 0 then
                  Invalid := True;
               else
                  Bits := Bits * 64 + Natural (V);
                  Bit_Count := Bit_Count + 6;
                  while Bit_Count >= 8 loop
                     Bit_Count := Bit_Count - 8;
                     Append_Decoded ((Bits / (2 ** Bit_Count)) mod 256);
                  end loop;
                  if Bit_Count = 0 then
                     Bits := 0;
                  else
                     Bits := Bits mod (2 ** Bit_Count);
                  end if;
               end if;
            end;

            exit when Invalid;
         end loop;
      end if;

      if Invalid then
         T.Clipboard_Data := (others => <>);
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      else
         T.Clipboard_Data.Pending := True;
         T.Clipboard_Data.Target := Target;
         T.Clipboard_Data.Length := Out_Len;
      end if;
   end Decode_OSC52;

   procedure Decode_OSC8
     (First : Natural;
      Last  : Natural)
   is
      URI_First : Natural := 0;
      Link      : Hyperlink;

      procedure Copy_URI (From : Natural; To : Natural) is
         Count : Natural := 0;
      begin
         if From > To then
            return;
         end if;

         for I in From .. To loop
            if Count < Max_Hyperlink_URI_Length then
               Count := Count + 1;
               Link.URI (Count) := T.OSC_Data (I);
            else
               T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
               exit;
            end if;
         end loop;
         Link.URI_Length := Count;
      end Copy_URI;

      procedure Copy_ID (From : Natural; To : Natural) is
         Count : Natural := 0;
      begin
         if From > To then
            return;
         end if;

         for I in From .. To loop
            if Count < Max_Hyperlink_ID_Length then
               Count := Count + 1;
               Link.ID (Count) := T.OSC_Data (I);
            else
               T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
               exit;
            end if;
         end loop;
         Link.ID_Length := Count;
      end Copy_ID;

      procedure Parse_Params (From : Natural; To : Natural) is
         I : Natural := From;
         Param_Start : Natural;
         Param_End   : Natural;
      begin
         if From > To then
            return;
         end if;

         while I <= To loop
            Param_Start := I;
            while I <= To and then T.OSC_Data (I) /= ':' loop
               I := I + 1;
            end loop;
            Param_End := I - 1;
            if Param_End >= Param_Start + 3
              and then T.OSC_Data (Param_Start) = 'i'
              and then T.OSC_Data (Param_Start + 1) = 'd'
              and then T.OSC_Data (Param_Start + 2) = '='
            then
               Copy_ID (Param_Start + 3, Param_End);
            end if;
            I := I + 1;
         end loop;
      end Parse_Params;
   begin
      for I in First .. Last loop
         if T.OSC_Data (I) = ';' then
            URI_First := I + 1;
            exit;
         end if;
      end loop;

      if URI_First = 0 then
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         return;
      elsif URI_First > Last then
         T.Current_Link := (others => <>);
         return;
      end if;

      Link := (others => <>);
      Link.Active := True;
      Parse_Params (First, URI_First - 2);
      Copy_URI (URI_First, Last);

      if Link.URI_Length = 0 then
         T.Current_Link := (others => <>);
      else
         T.Current_Link := Link;
      end if;
   end Decode_OSC8;
begin
   if T.OSC_Count < 3 then
      T.State := Ground;
      return;
   end if;

   for I in 1 .. T.OSC_Count loop
      if T.OSC_Data (I) = ';' then
         Payload_First := I + 1;
         exit;
      elsif T.OSC_Data (I) in '0' .. '9' then
         Command :=
           Natural'Min
             (Command * 10
              + Standard.Character'Pos (T.OSC_Data (I))
              - Standard.Character'Pos ('0'),
              Natural'Last / 2);
      else
         T.State := Ground;
         return;
      end if;
   end loop;

   if Payload_First = 0 then
      T.State := Ground;
      return;
   end if;

   if Command in 0 .. 2 then
      Title_Length :=
        Natural'Min
          (T.OSC_Count - Payload_First + 1,
           Max_Title_Length);
      T.Window_Title := (others => <>);
      T.Window_Title.Length := Title_Length;
      for I in 1 .. Title_Length loop
         T.Window_Title.Text (I) := T.OSC_Data (Payload_First + I - 1);
      end loop;
   elsif Command = Private_Identity_OSC
     and then T.OSC_Count - Payload_First + 1 = 1
     and then T.OSC_Data (Payload_First) = 'q'
   then
      Queue_Identity_Report (T);
   elsif Command = 8 then
      Decode_OSC8 (Payload_First, T.OSC_Count);
   elsif Command = 52 then
      Decode_OSC52 (Payload_First, T.OSC_Count);
   elsif Command = 1337
     and then T.OSC_Count - Payload_First + 1 = 12
     and then OSC_Slice (T, Payload_First, T.OSC_Count) = "Capabilities"
   then
      Begin_Response (T);
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_String (T, "]1337;Capabilities=");
      if T.Graphics_Capabilities.ITerm2_Inline_Images
        and then T.Graphics_Capabilities.ITerm2_File_Downloads
      then
         Append_Response_Char (T, 'F');
      end if;
      if T.Graphics_Capabilities.Sixel then
         Append_Response_String (T, "Sx");
      end if;
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_Char (T, '\');
      End_Response (T);
   elsif Command = 1337 and then Payload_Starts_With ("File=") then
      Note_Graphics_Protocol
        (T,
         Graphics_ITerm2,
         T.OSC_Count - Payload_First + 1,
         OSC_Slice (T, Payload_First, T.OSC_Count));
   elsif Command = 1337
     and then Payload_Starts_With ("MultipartFile=")
   then
      Clear_ITerm2_Multipart (T);
      T.ITerm2_Multipart_Active := True;
      declare
         Accepted : Boolean := Append_ITerm2_Multipart (T, "File=");
      begin
         if Accepted and then Payload_First + 14 <= T.OSC_Count then
            Accepted := Append_ITerm2_Multipart
              (T, OSC_Slice (T, Payload_First + 14, T.OSC_Count));
         end if;
         if Accepted then
            Accepted := Append_ITerm2_Multipart (T, ":");
         end if;
         if not Accepted then
            Clear_ITerm2_Multipart (T);
         end if;
      end;
   elsif Command = 1337
     and then Payload_Starts_With ("FilePart=")
     and then T.ITerm2_Multipart_Active
   then
      declare
         Accepted : Boolean := True;
      begin
         if Payload_First + 9 <= T.OSC_Count then
            Accepted := Append_ITerm2_Multipart
              (T, OSC_Slice (T, Payload_First + 9, T.OSC_Count));
         end if;
         if not Accepted then
            Clear_ITerm2_Multipart (T);
         end if;
      end;
   elsif Command = 1337
     and then T.ITerm2_Multipart_Active
     and then T.OSC_Count - Payload_First + 1 = 7
     and then OSC_Slice (T, Payload_First, T.OSC_Count) = "FileEnd"
   then
      if T.ITerm2_Multipart /= null
        and then T.ITerm2_Multipart_Length > 6
      then
         Note_Graphics_Protocol
           (T,
            Graphics_ITerm2,
            T.ITerm2_Multipart_Length,
            T.ITerm2_Multipart (1 .. T.ITerm2_Multipart_Length));
      end if;
      Clear_ITerm2_Multipart (T);
   end if;

   T.State := Ground;
end Finish_OSC;
