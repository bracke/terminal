with Terminal.App.PTY_Write;
with Terminal.App.Renderer;
with Terminal.App.Session_Table;
with Terminal.App.Splits;

package Terminal.App.Session_Graphics is
   --  Consume at most one graphics command from each non-visible session.
   --  This keeps protocol queries, chunks, and parser backpressure moving even
   --  while another tab is selected.
   procedure Process_Hidden
     (Table        : in out Terminal.App.Session_Table.Runtime_Table;
      Splits       : Terminal.App.Splits.Split_State;
      Renderer     : in out Terminal.App.Renderer.Renderer;
      Processed    : out Boolean;
      Render_Status : out Terminal.App.Renderer.Render_Status;
      Write_Status : out Terminal.App.PTY_Write.Write_All_Status);
end Terminal.App.Session_Graphics;
