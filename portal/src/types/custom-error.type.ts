export class CustomError extends Error {
  errorCode?: string;

  constructor(message: string, errorCode?: string) {
    super(message);
    this.name = 'CustomError';
    this.errorCode = errorCode;

    // Required for extending built-in classes like Error
    Object.setPrototypeOf(this, new.target.prototype);
  }
}
