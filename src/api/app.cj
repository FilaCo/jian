protected package jian.api

import result_cj.Result

public func commandLine(): AppBuilder {
    App.builder()
}

public class App {
    App() {}

    protected static func builder(): AppBuilder {
        AppBuilder()
    }

    public operator func ()(args: Array<String>): Unit {
    }
}

public class AppBuilder {
    AppBuilder() {
    }

    public func build(): Result<App, AppBuildError> {
        Ok(App())
    }

    public func add(builder: AppBuilder, name!: ?String = None, help!: ?String = None): This {
        this
    }

    public func add<F>(command: F): This {
        this
    }

    public func callback<F>(callback: F): This {
        this
    }

    public operator func ()(args: Array<String>): Unit {
        build().map {app => app(args)}.unwrap()
    }
}

type AppBuildError = String
