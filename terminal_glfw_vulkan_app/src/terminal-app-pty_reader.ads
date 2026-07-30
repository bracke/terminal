with Terminal.PTY.Backend;
with Terminal.App.Queues;

package Terminal.App.PTY_Reader is
   task type Reader
     (Session : access Terminal.PTY.Backend.Session;
      Queue   : access Terminal.App.Queues.PTY_Output_Queue) is
      entry Stop;
   end Reader;
end Terminal.App.PTY_Reader;
