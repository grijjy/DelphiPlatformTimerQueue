program TimerQueuesConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  Grijjy.TimerQueue;

type
  TMyClass = class
    procedure OnTimer(const ASender: TObject);
  end;

var
  TimerQueue: TgoTimerQueue;
  MyClass: TMyClass;

{ TMyClass }

procedure TMyClass.OnTimer(const ASender: TObject);
var
  S: String;
  Timer: TgoTimer;
begin
  Timer := ASender as TgoTimer;
  S := (Format('OnTimer (%s, Thread=%s, Interval=%d)',
    [UInt32(Timer.Handle).ToHexString, TThread.CurrentThread.ThreadID.ToHexString, Timer.Interval]));

  Writeln(S); // The console is not thread safe
end;

begin
  ReportMemoryLeaksOnShutDown := True;

  try
    TimerQueue := TgoTimerQueue.Create;
    try
      MyClass := TMyClass.Create;
      try
        TimerQueue.Add(1000, MyClass.OnTimer);
        TimerQueue.Add(500, MyClass.OnTimer);
        TimerQueue.Add(100, MyClass.OnTimer);

        Readln;
      finally
        MyClass.Free;
      end;
    finally
      TimerQueue.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
