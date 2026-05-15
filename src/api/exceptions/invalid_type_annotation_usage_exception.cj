protected package jian.api.exceptions

public class InvalidTypeAnnotationUsageException <: Exception {
    protected InvalidTypeAnnotationUsageException(typeAnnotationName: String) {
        super(
            "${typeAnnotationName} can appear only as an argument default value of function modified by the @Command macro.")
    }

    protected func getClassName(): String {
        "InvalidTypeAnnotationUsageException"
    }
}
