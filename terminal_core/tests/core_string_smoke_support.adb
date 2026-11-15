with Ada.Strings.Unbounded;
with Terminal.Core;
with Terminal.Core.Parser;

package body Core_String_Smoke_Support is
   package Unbounded renames Ada.Strings.Unbounded;
   use Terminal.Common.Bytes;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   function Repeat_Char (Ch : Character; Count : Natural) return String is
      Result : String (1 .. Count) := (others => Ch);
   begin
      return Result;
   end Repeat_Char;

   function Wrap_Tmux (Text : String) return String is
      Result : Unbounded.Unbounded_String :=
        Unbounded.To_Unbounded_String (ASCII.ESC & "Ptmux;");
   begin
      for Ch of Text loop
         if Ch = ASCII.ESC then
            Unbounded.Append (Result, ASCII.ESC);
         end if;
         Unbounded.Append (Result, Ch);
      end loop;
      Unbounded.Append (Result, ASCII.ESC & "\");
      return Unbounded.To_String (Result);
   end Wrap_Tmux;

   function DCS_Overflow_Fixture return Byte_Array is
      Payload_Length : constant Natural :=
        Terminal.Core.Parser.Max_Escape_Length + 5;
      Result : Byte_Array (1 .. Payload_Length + 4);
   begin
      Result (1) := 16#1B#;
      Result (2) := Byte (Character'Pos ('P'));
      for I in 1 .. Payload_Length loop
         Result (I + 2) := Byte (Character'Pos ('a'));
      end loop;
      Result (Result'Last - 1) := 16#1B#;
      Result (Result'Last) := Byte (Character'Pos ('\'));
      return Result;
   end DCS_Overflow_Fixture;

   function Long_Title_Fixture return Byte_Array is
      Payload_Length : constant Natural := Terminal.Core.Max_Title_Length + 20;
      Result : Byte_Array (1 .. Payload_Length + 5);
   begin
      Result (1) := 16#1B#;
      Result (2) := Byte (Character'Pos (']'));
      Result (3) := Byte (Character'Pos ('1'));
      Result (4) := Byte (Character'Pos (';'));
      for I in 1 .. Payload_Length loop
         Result (I + 4) := Byte (Character'Pos ('A'));
      end loop;
      Result (Result'Last) := 16#07#;
      return Result;
   end Long_Title_Fixture;
end Core_String_Smoke_Support;
