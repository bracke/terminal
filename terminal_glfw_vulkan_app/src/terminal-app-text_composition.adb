package body Terminal.App.Text_Composition is
   function Hex_Value (Digit : Character) return Natural is
   begin
      if Digit in '0' .. '9' then
         return Character'Pos (Digit) - Character'Pos ('0');
      elsif Digit in 'a' .. 'f' then
         return Character'Pos (Digit) - Character'Pos ('a') + 10;
      elsif Digit in 'A' .. 'F' then
         return Character'Pos (Digit) - Character'Pos ('A') + 10;
      else
         return 16;
      end if;
   end Hex_Value;

   procedure Begin_Composition (Item : out State) is
   begin
      Item := (Is_Active => True, others => <>);
   end Begin_Composition;

   procedure Cancel (Item : in out State) is
   begin
      Item := (others => <>);
   end Cancel;

   procedure Append (Item : in out State; Digit : Character) is
   begin
      if Item.Is_Active and then Item.Length < Max_Digits
        and then Hex_Value (Digit) < 16
      then
         Item.Length := Item.Length + 1;
         Item.Buffer (Item.Length) := Digit;
      end if;
   end Append;

   procedure Backspace (Item : in out State) is
   begin
      if Item.Is_Active and then Item.Length > 0 then
         Item.Buffer (Item.Length) := '0';
         Item.Length := Item.Length - 1;
      end if;
   end Backspace;

   procedure Commit
     (Item       : in out State;
      Code_Point : out Wide_Wide_Character;
      Valid      : out Boolean)
   is
      Value : Natural := 0;
   begin
      Valid := Item.Is_Active and then Item.Length > 0;
      if Valid then
         for I in 1 .. Item.Length loop
            Value := Value * 16 + Hex_Value (Item.Buffer (I));
         end loop;
         Valid := Value <= 16#10_FFFF#
           and then Value not in 16#D800# .. 16#DFFF#;
      end if;
      Code_Point :=
        (if Valid then Wide_Wide_Character'Val (Value)
         else Wide_Wide_Character'Val (0));
      Cancel (Item);
   end Commit;

   function Active (Item : State) return Boolean is (Item.Is_Active);

   function Text (Item : State) return String is
   begin
      if Item.Length = 0 then
         return "";
      end if;
      return Item.Buffer (1 .. Item.Length);
   end Text;

   function Status_Label (Item : State) return String is
   begin
      if not Item.Is_Active then
         return "";
      elsif Item.Length = 0 then
         return "Compose U+_";
      else
         return "Compose U+" & Text (Item) & "_";
      end if;
   end Status_Label;
end Terminal.App.Text_Composition;
