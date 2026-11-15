package body Terminal.Common.UTF8 is
   procedure Decode_UTF16
     (Value  : String;
      Result : out UTF16_Array;
      Length : out Natural;
      Valid  : out Boolean)
   is
      Position : Integer := Value'First;

      function Has_Capacity (Count : Positive) return Boolean is
        (Length < Result'Length
         and then Count <= Result'Length - Length - 1);

      function Continuation (Offset : Natural) return Natural is
        (Character'Pos (Value (Position + Integer (Offset))) - 16#80#);

      procedure Append (Code_Point : Natural) is
         Rest : Natural;
         Target_Index : Natural;
      begin
         if Code_Point <= 16#FFFF# then
            if not Has_Capacity (1) then
               Valid := False;
               return;
            end if;
            Target_Index := Result'First + Length;
            Result (Target_Index) := UTF16_Unit (Code_Point);
            Length := Length + 1;
         else
            if not Has_Capacity (2) then
               Valid := False;
               return;
            end if;
            Rest := Code_Point - 16#10000#;
            Target_Index := Result'First + Length;
            Result (Target_Index) :=
              UTF16_Unit (16#D800# + Rest / 16#400#);
            Result (Target_Index + 1) :=
              UTF16_Unit (16#DC00# + Rest mod 16#400#);
            Length := Length + 2;
         end if;
      end Append;
   begin
      Result := (others => 0);
      Length := 0;
      Valid := Result'Length > 0;
      if not Valid then
         return;
      end if;

      while Position <= Value'Last loop
         declare
            First : constant Natural := Character'Pos (Value (Position));
            Code_Point : Natural;
            Width : Positive;
         begin
            if First < 16#80# then
               Code_Point := First;
               Width := 1;
            elsif First in 16#C2# .. 16#DF# then
               Code_Point := First mod 16#20#;
               Width := 2;
            elsif First in 16#E0# .. 16#EF# then
               Code_Point := First mod 16#10#;
               Width := 3;
            elsif First in 16#F0# .. 16#F4# then
               Code_Point := First mod 16#08#;
               Width := 4;
            else
               Valid := False;
               return;
            end if;

            if Position > Value'Last - Width + 1 then
               Valid := False;
               return;
            end if;
            for Offset in 1 .. Width - 1 loop
               if Character'Pos (Value (Position + Offset)) not in
                 16#80# .. 16#BF#
               then
                  Valid := False;
                  return;
               end if;
               Code_Point := Code_Point * 64 + Continuation (Offset);
            end loop;
            if (Width = 3 and then Code_Point < 16#800#)
              or else (Width = 4 and then Code_Point < 16#10000#)
              or else Code_Point in 16#D800# .. 16#DFFF#
              or else Code_Point > 16#10FFFF#
            then
               Valid := False;
               return;
            end if;

            Append (Code_Point);
            if not Valid then
               return;
            end if;
            Position := Position + Width;
         end;
      end loop;
      Result (Result'First + Length) := 0;
   end Decode_UTF16;
end Terminal.Common.UTF8;
