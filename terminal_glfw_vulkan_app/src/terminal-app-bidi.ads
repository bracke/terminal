with Terminal.App.Render_Model;

package Terminal.App.Bidi is
   type Resolve_Status is (Resolved, Invalid_Input, Backend_Failure);
   type Paragraph_Direction is (Left_To_Right, Right_To_Left);

   type Codepoint_Array is array (Positive range <>) of Natural;
   type Visual_Position_Array is array (Positive range <>) of Natural;
   type Embedding_Level_Array is array (Positive range <>) of Natural;

   procedure Resolve
     (Logical           : Codepoint_Array;
      Logical_To_Visual : out Visual_Position_Array;
      Levels            : out Embedding_Level_Array;
      Visual            : out Codepoint_Array;
      Base              : out Paragraph_Direction;
      Status            : out Resolve_Status);

   --  Runs may only collapse adjacent cells when doing so preserves the
   --  sequence of BiDi classes that FriBidi must resolve.  Neutral and
   --  separator characters stay separate (except ordinary whitespace), so
   --  bracket pairing and weak/neutral resolution retain their inputs.
   function Can_Join (Left, Right : Natural) return Boolean;

   function Direction_For
     (Level : Natural) return Terminal.App.Render_Model.Text_Run_Direction;
end Terminal.App.Bidi;
