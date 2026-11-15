with Terminal.App.Selection;
with Terminal.Core;

package Terminal.App.Shell_Blocks is
   Max_Command_Length : constant := 4_096;
   Max_Status_Label_Length : constant := 96;

   function Latest (T : Terminal.Core.Terminal) return Terminal.Core.Shell_Command_Block;
   function Command_Text
     (T     : Terminal.Core.Terminal;
      Block : Terminal.Core.Shell_Command_Block) return String;
   function Recommended_Offset
     (T     : Terminal.Core.Terminal;
      Block : Terminal.Core.Shell_Command_Block) return Natural;
   procedure Visible_Range
     (T       : Terminal.Core.Terminal;
      Block   : Terminal.Core.Shell_Command_Block;
      Offset  : Natural;
      First   : out Terminal.App.Selection.Cell_Position;
      Last    : out Terminal.App.Selection.Cell_Position;
      Visible : out Boolean);
   function Status_Label (Block : Terminal.Core.Shell_Command_Block) return String;
end Terminal.App.Shell_Blocks;
