with Ada.Strings.Unbounded;
with Terminal.Common;

package body Terminal.App.Screen_Text is
   use Ada.Strings.Unbounded;
   use type Terminal.Core.Cell_Kind;

   function UTF8 (Code : Terminal.Common.Code_Point) return String is
      Value : Natural := Natural (Code);
   begin
      if Value = 0 or else Value > 16#10FFFF#
        or else Value in 16#D800# .. 16#DFFF#
      then
         Value := 16#FFFD#;
      end if;
      if Value <= 16#7F# then
         return [Character'Val (Value)];
      elsif Value <= 16#7FF# then
         return [Character'Val (16#C0# + Value / 64),
                 Character'Val (16#80# + Value mod 64)];
      elsif Value <= 16#FFFF# then
         return [Character'Val (16#E0# + Value / 4_096),
                 Character'Val (16#80# + (Value / 64) mod 64),
                 Character'Val (16#80# + Value mod 64)];
      else
         return [Character'Val (16#F0# + Value / 262_144),
                 Character'Val (16#80# + (Value / 4_096) mod 64),
                 Character'Val (16#80# + (Value / 64) mod 64),
                 Character'Val (16#80# + Value mod 64)];
      end if;
   end UTF8;

   function Visible
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Max_Bytes : Natural := Natural'Last) return String
   is
      Result : Unbounded_String;
      Full : Boolean := False;

      procedure Append_Bounded (Text : String) is
      begin
         if Text'Length <= Max_Bytes - Natural'Min (Length (Result), Max_Bytes)
         then
            Append (Result, Text);
         else
            Full := True;
         end if;
      end Append_Bounded;
   begin
      if Max_Bytes = 0 or else Snapshot.Rows = 0 or else Snapshot.Cols = 0 then
         return "";
      end if;
      for Row in 1 .. Snapshot.Rows loop
         declare
            Row_Text : Unbounded_String;
            Significant : Natural := 0;
         begin
            for Col in 1 .. Snapshot.Cols loop
               declare
                  Cell : constant Terminal.Core.Cell_Content :=
                    Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
               begin
                  if Cell.Kind = Terminal.Core.Character then
                     Append (Row_Text, UTF8 (Cell.Text.Code_Point));
                     for I in 1 .. Cell.Text.Attachment_Count loop
                        Append (Row_Text, UTF8 (Cell.Text.Attachments (I)));
                     end loop;
                     Significant := Length (Row_Text);
                  elsif Cell.Kind = Terminal.Core.Empty then
                     Append (Row_Text, ' ');
                  end if;
               end;
            end loop;
            if Row > 1 then
               Append_Bounded ([ASCII.LF]);
            end if;
            if not Full and then Significant > 0 then
               Append_Bounded (Slice (Row_Text, 1, Significant));
            end if;
            exit when Full;
         end;
      end loop;
      return To_String (Result);
   end Visible;
end Terminal.App.Screen_Text;
