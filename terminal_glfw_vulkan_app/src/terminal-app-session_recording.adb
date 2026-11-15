with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Text_IO;
with Terminal.Common;
with Terminal.Common.Bytes;

package body Terminal.App.Session_Recording is
   use type Ada.Real_Time.Time;
   use type Terminal.Core.Cell_Kind;

   Hex : constant String := "0123456789ABCDEF";
   Header : constant String := "ADA_TERMINAL_RECORDING";
   Header_Prefix : constant String := Header & " 1 ";

   function Trim (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Both));

   function Trim (Value : Terminal.Core.Graphics_Stream_ID) return String is
     (Ada.Strings.Fixed.Trim
        (Terminal.Core.Graphics_Stream_ID'Image (Value), Ada.Strings.Both));

   function Valid_Header (Text : String) return Boolean is
      Separator : Natural;
      Rows, Cols : Positive;
   begin
      if Text'Length <= Header_Prefix'Length
        or else Text (Text'First .. Text'First + Header_Prefix'Length - 1) /=
          Header_Prefix
      then
         return False;
      end if;
      Separator := Ada.Strings.Fixed.Index
        (Text, " ", Text'First + Header_Prefix'Length);
      if Separator = 0 or else Separator = Text'Last then
         return False;
      end if;
      Rows := Positive'Value
        (Text (Text'First + Header_Prefix'Length .. Separator - 1));
      Cols := Positive'Value (Text (Separator + 1 .. Text'Last));
      return Rows > 0 and then Cols > 0;
   exception
      when Constraint_Error => return False;
   end Valid_Header;

   procedure Start
     (Item   : in out State;
      Path   : String;
      Rows   : Positive;
      Cols   : Positive;
      Status : out IO_Status) is
   begin
      if Path = "" then
         Status := Invalid_Path;
         return;
      end if;
      if Item.Is_Active then
         Ada.Text_IO.Close (Item.File);
         Item.Is_Active := False;
      end if;
      Ada.Text_IO.Create (Item.File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (Item.File,
         "ADA_TERMINAL_RECORDING 1 " & Trim (Rows) & " " & Trim (Cols));
      Ada.Text_IO.Flush (Item.File);
      Item.Started_At := Ada.Real_Time.Clock;
      Item.Events := 0;
      Item.Is_Active := True;
      Status := Ok;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Item.File) then Ada.Text_IO.Close (Item.File); end if;
         Item.Is_Active := False;
         Status := IO_Error;
   end Start;

   procedure Stop (Item : in out State; Status : out IO_Status) is
   begin
      if not Item.Is_Active then
         Status := Not_Recording;
         return;
      end if;
      Ada.Text_IO.Close (Item.File);
      Item.Is_Active := False;
      Status := Ok;
   exception
      when others =>
         Item.Is_Active := False;
         Status := IO_Error;
   end Stop;

   function Active (Item : State) return Boolean is (Item.Is_Active);

   procedure Record_Output
     (Item    : in out State;
      Stream  : Terminal.Core.Graphics_Stream_ID;
      Chunk   : Terminal.App.Queues.Byte_Chunk)
   is
   begin
      if not Item.Is_Active or else Chunk.Length = 0 then return; end if;
      declare
         Elapsed : constant Duration :=
           Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Item.Started_At);
         Data : String (1 .. Chunk.Length * 2);
      begin
         for I in 1 .. Chunk.Length loop
            Data (I * 2 - 1) := Hex (Natural (Chunk.Data (I)) / 16 + 1);
            Data (I * 2) := Hex (Natural (Chunk.Data (I)) mod 16 + 1);
         end loop;
         Ada.Text_IO.Put_Line
           (Item.File,
            Ada.Strings.Fixed.Trim (Duration'Image (Elapsed), Ada.Strings.Both)
              & "|" & Trim (Stream) & "|" & Data);
         Item.Events := Item.Events + 1;
         if Item.Events mod 64 = 0 then
            Ada.Text_IO.Flush (Item.File);
         end if;
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Item.File) then Ada.Text_IO.Close (Item.File); end if;
         Item.Is_Active := False;
   end Record_Output;

   function Hex_Value (Ch : Character; Valid : out Boolean) return Natural is
      Upper : constant Character := Ada.Characters.Handling.To_Upper (Ch);
   begin
      Valid := True;
      if Upper in '0' .. '9' then
         return Character'Pos (Upper) - Character'Pos ('0');
      elsif Upper in 'A' .. 'F' then
         return Character'Pos (Upper) - Character'Pos ('A') + 10;
      end if;
      Valid := False;
      return 0;
   end Hex_Value;

   procedure Replay
     (Path   : String;
      Sink   : not null access procedure
        (Stream  : Terminal.Core.Graphics_Stream_ID;
         Chunk   : Terminal.App.Queues.Byte_Chunk);
      Status : out IO_Status)
   is
      File : Ada.Text_IO.File_Type;
      Line : Ada.Strings.Unbounded.Unbounded_String;
      function Next_Bar (Text : String; After : Natural) return Natural is
      begin
         for I in Natural'Max (Text'First, After + 1) .. Text'Last loop
            if Text (I) = '|' then return I; end if;
         end loop;
         return 0;
      end Next_Bar;
   begin
      if Path = "" then Status := Invalid_Path; return; end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Close (File);
         Status := Invalid_Format;
         return;
      end if;
      Line := Ada.Strings.Unbounded.Text_IO.Get_Line (File);
      if not Valid_Header (Ada.Strings.Unbounded.To_String (Line)) then
         Ada.Text_IO.Close (File);
         Status := Invalid_Format;
         return;
      end if;
      while not Ada.Text_IO.End_Of_File (File) loop
         Line := Ada.Strings.Unbounded.Text_IO.Get_Line (File);
         declare
            Text : constant String := Ada.Strings.Unbounded.To_String (Line);
            First_Bar : constant Natural := Ada.Strings.Fixed.Index (Text, "|");
            Second_Bar : constant Natural :=
              Next_Bar (Text, First_Bar);
            Chunk : Terminal.App.Queues.Byte_Chunk;
            Stream : Terminal.Core.Graphics_Stream_ID := 0;
            Elapsed : Duration := 0.0;
            Valid : Boolean := True;
         begin
            if First_Bar <= Text'First
              or else Second_Bar <= First_Bar + 1
              or else (Text'Last - Second_Bar) mod 2 /= 0
            then
               Valid := False;
            else
               Elapsed := Duration'Value (Text (Text'First .. First_Bar - 1));
               Stream := Terminal.Core.Graphics_Stream_ID'Value
                 (Text (First_Bar + 1 .. Second_Bar - 1));
               Chunk.Length := (Text'Last - Second_Bar) / 2;
               Valid := Elapsed >= 0.0
                 and then Chunk.Length <= Terminal.App.Queues.Max_Chunk_Length;
               for I in 1 .. Chunk.Length loop
                  exit when not Valid;
                  declare
                     High_Valid, Low_Valid : Boolean;
                     High : constant Natural :=
                       Hex_Value (Text (Second_Bar + I * 2 - 1), High_Valid);
                     Low : constant Natural :=
                       Hex_Value (Text (Second_Bar + I * 2), Low_Valid);
                  begin
                     Valid := High_Valid and then Low_Valid;
                     if Valid then
                        Chunk.Data (I) := Terminal.Common.Bytes.Byte (High * 16 + Low);
                     end if;
                  end;
               end loop;
            end if;
            if not Valid then
               Ada.Text_IO.Close (File);
               Status := Invalid_Format;
               return;
            end if;
            Sink (Stream, Chunk);
         exception
            when Constraint_Error =>
               Ada.Text_IO.Close (File);
               Status := Invalid_Format;
               return;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      Status := Ok;
   exception
      when Ada.Text_IO.Name_Error => Status := Invalid_Path;
      when others =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         Status := IO_Error;
   end Replay;

   procedure Append_UTF8
     (Text : in out Ada.Strings.Unbounded.Unbounded_String;
      Code : Terminal.Common.Code_Point)
   is
      Value : Natural := Natural (Code);
      procedure Put (Byte : Natural) is
      begin
         Ada.Strings.Unbounded.Append (Text, Character'Val (Byte));
      end Put;
   begin
      if Value = 0 or else Value > 16#10FFFF#
        or else Value in 16#D800# .. 16#DFFF#
      then Value := 16#FFFD#; end if;
      if Value <= 16#7F# then Put (Value);
      elsif Value <= 16#7FF# then
         Put (16#C0# + Value / 64); Put (16#80# + Value mod 64);
      elsif Value <= 16#FFFF# then
         Put (16#E0# + Value / 4_096);
         Put (16#80# + (Value / 64) mod 64); Put (16#80# + Value mod 64);
      else
         Put (16#F0# + Value / 262_144);
         Put (16#80# + (Value / 4_096) mod 64);
         Put (16#80# + (Value / 64) mod 64); Put (16#80# + Value mod 64);
      end if;
   end Append_UTF8;

   procedure Export_Transcript
     (Core   : Terminal.Core.Terminal;
      Path   : String;
      Status : out IO_Status)
   is
      File : Ada.Text_IO.File_Type;
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Core);
      History : constant Natural := Terminal.Core.Scrollback_Row_Count (Core);
      Cols : constant Positive := Positive (Snapshot.Cols);
      procedure Write_Row (Absolute_Row : Positive) is
         Text : Ada.Strings.Unbounded.Unbounded_String;
         Significant : Natural := 0;
      begin
         for Col in 1 .. Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 (if Absolute_Row <= History
                  then Terminal.Core.Scrollback_Cell_At (Core, Absolute_Row, Col)
                  else Terminal.Core.Cell_At
                    (Snapshot, Absolute_Row - History, Col));
            begin
               if Cell.Kind = Terminal.Core.Wide_Continuation then null;
               elsif Cell.Kind = Terminal.Core.Character then
                  Append_UTF8 (Text, Cell.Text.Code_Point);
                  for I in 1 .. Cell.Text.Attachment_Count loop
                     Append_UTF8 (Text, Cell.Text.Attachments (I));
                  end loop;
                  Significant := Ada.Strings.Unbounded.Length (Text);
               else
                  Ada.Strings.Unbounded.Append (Text, ' ');
               end if;
            end;
         end loop;
         Ada.Text_IO.Put_Line
           (File,
            (if Significant = 0 then ""
             else Ada.Strings.Unbounded.Slice (Text, 1, Significant)));
      end Write_Row;
   begin
      if Path = "" then Status := Invalid_Path; Terminal.Core.Release (Snapshot); return; end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      for Row in 1 .. History + Snapshot.Rows loop
         Write_Row (Row);
      end loop;
      Ada.Text_IO.Close (File);
      Terminal.Core.Release (Snapshot);
      Status := Ok;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         Terminal.Core.Release (Snapshot);
         Status := IO_Error;
   end Export_Transcript;

   function Status_Label (Item : State) return String is
     (if Item.Is_Active then "RECORDING (" & Trim (Item.Events) & " events)"
      else "");
end Terminal.App.Session_Recording;
