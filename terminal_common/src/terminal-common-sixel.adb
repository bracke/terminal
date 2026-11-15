package body Terminal.Common.Sixel is
   procedure Skip_Number (Text : String; Index : in out Natural) is
   begin
      while Index <= Text'Last and then Text (Index) in '0' .. '9' loop
         Index := Index + 1;
      end loop;
   end Skip_Number;

   function Read_Number
     (Text : String; Index : in out Natural) return Natural
   is
      Value : Natural := 0;
      Seen  : Boolean := False;
   begin
      while Index <= Text'Last and then Text (Index) in '0' .. '9' loop
         Seen := True;
         declare
            Digit : constant Natural :=
              Character'Pos (Text (Index)) - Character'Pos ('0');
         begin
            if Value > (Natural'Last - Digit) / 10 then
               Value := Natural'Last;
            else
               Value := Value * 10 + Digit;
            end if;
         end;
         Index := Index + 1;
      end loop;
      return (if Seen then Value else 0);
   end Read_Number;

   function Analyze (Text : String) return Analysis is
      I               : Natural := Text'First;
      X               : Natural := 0;
      Y               : Natural := 0;
      Max_X           : Natural := 0;
      Max_Y           : Natural := 0;
      Repeat_Count    : Natural := 1;
      Declared_Width  : Natural := 0;
      Declared_Height : Natural := 0;
      Vertical_Aspect : Positive := 1;
      Transparent     : Boolean := False;

      procedure Add_X (Amount : Natural) is
      begin
         if X > Natural'Last - Amount then
            X := Natural'Last;
         else
            X := X + Amount;
         end if;
      end Add_X;
   begin
      while I <= Text'Last and then Text (I) /= 'q' loop
         I := I + 1;
      end loop;
      if I > Text'Last then
         return (others => <>);
      end if;

      declare
         J           : Natural := Text'First;
         Aspect_Code : Natural := 0;
      begin
         if J < I and then Text (J) in '0' .. '9' then
            Aspect_Code := Read_Number (Text, J);
            Vertical_Aspect :=
              (case Aspect_Code is
                  when 0 | 1 | 5 | 6 => 2,
                  when 2 => 5,
                  when 3 | 4 => 3,
                  when others => 1);
         end if;
      end;

      declare
         J         : Natural := Text'First;
         Parameter : Natural := 1;
      begin
         while J < I loop
            if Text (J) = ';' then
               Parameter := Parameter + 1;
               J := J + 1;
            elsif Parameter = 2 then
               Transparent := Read_Number (Text, J) = 1;
               exit;
            else
               declare
                  Before : constant Natural := J;
               begin
                  Skip_Number (Text, J);
                  if J = Before then
                     --  Private or malformed introducer bytes are ignored,
                     --  but must not stall analysis of the raster payload.
                     J := J + 1;
                  end if;
               end;
            end if;
         end loop;
      end;

      I := I + 1;
      while I <= Text'Last loop
         case Text (I) is
            when '!' =>
               I := I + 1;
               Repeat_Count := Natural'Max (Read_Number (Text, I), 1);
            when '#' =>
               I := I + 1;
               Skip_Number (Text, I);
               while I <= Text'Last and then Text (I) = ';' loop
                  I := I + 1;
                  Skip_Number (Text, I);
               end loop;
            when '"' =>
               I := I + 1;
               declare
                  Pan : constant Natural := Read_Number (Text, I);
                  Pad : Natural := 0;
               begin
                  if I <= Text'Last and then Text (I) = ';' then
                     I := I + 1;
                     Pad := Read_Number (Text, I);
                  end if;
                  if Pan > 0 and then Pad > 0 then
                     declare
                        Ratio : constant Natural :=
                          Pan / Pad + (if Pan mod Pad = 0 then 0 else 1);
                     begin
                        Vertical_Aspect :=
                          Positive (Natural'Max (Ratio, 1));
                     end;
                  end if;
               end;
               if I <= Text'Last and then Text (I) = ';' then
                  I := I + 1;
                  Declared_Width := Read_Number (Text, I);
               end if;
               if I <= Text'Last and then Text (I) = ';' then
                  I := I + 1;
                  Declared_Height := Read_Number (Text, I);
               end if;
            when '$' =>
               X := 0;
               I := I + 1;
            when '-' =>
               X := 0;
               if Y > Natural'Last - 6 then
                  Y := Natural'Last;
               else
                  Y := Y + 6;
               end if;
               Max_Y := Natural'Max (Max_Y, Y);
               I := I + 1;
            when '?' .. '~' =>
               Add_X (Repeat_Count);
               Max_X := Natural'Max (Max_X, X);
               Max_Y :=
                 Natural'Max
                   (Max_Y,
                    (if Y > Natural'Last - 6
                     then Natural'Last else Y + 6));
               Repeat_Count := 1;
               I := I + 1;
            when others =>
               Repeat_Count := 1;
               I := I + 1;
         end case;
      end loop;

      Max_X := Natural'Max (Max_X, Declared_Width);
      Max_Y := Natural'Max (Max_Y, Declared_Height);
      if Max_X = 0 or else Max_Y = 0 then
         return
           (Width           => 0,
            Height          => 0,
            Logical_Height  => 0,
            Vertical_Aspect => Vertical_Aspect,
            Transparent     => Transparent);
      end if;
      return
        (Width           => Max_X,
         Height          =>
           (if Max_Y > Natural'Last / Vertical_Aspect
            then Natural'Last else Max_Y * Vertical_Aspect),
         Logical_Height  => Max_Y,
         Vertical_Aspect => Vertical_Aspect,
         Transparent     => Transparent);
   end Analyze;
end Terminal.Common.Sixel;
