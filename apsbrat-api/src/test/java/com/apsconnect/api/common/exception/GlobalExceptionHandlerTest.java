package com.apsconnect.api.common.exception;

import com.apsconnect.api.common.response.ApiResponse;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void appExceptionMapsStatusAndCode() {
        ResponseEntity<ApiResponse<Void>> resp =
                handler.handleApp(new AppException("Community not found", HttpStatus.NOT_FOUND));

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().isSuccess()).isFalse();
        assertThat(resp.getBody().getCode()).isEqualTo("NOT_FOUND");
        assertThat(resp.getBody().getError()).isEqualTo("Community not found");
    }

    @Test
    void validationErrorReturns400WithFieldMessages() {
        var br = new BeanPropertyBindingResult(new Object(), "request");
        br.addError(new FieldError("request", "phone", "must not be blank"));
        var ex = mock(MethodArgumentNotValidException.class);
        when(ex.getBindingResult()).thenReturn(br);

        ResponseEntity<ApiResponse<Void>> resp = handler.handleValidation(ex);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody().getCode()).isEqualTo("VALIDATION_ERROR");
        assertThat(resp.getBody().getError()).contains("phone: must not be blank");
    }

    @Test
    void badRequestForMissingParam() {
        ResponseEntity<ApiResponse<Void>> resp =
                handler.handleBadRequest(new MissingServletRequestParameterException("q", "String"));

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody().getCode()).isEqualTo("BAD_REQUEST");
    }

    @Test
    void methodNotAllowed() {
        ResponseEntity<ApiResponse<Void>> resp =
                handler.handleMethod(new HttpRequestMethodNotSupportedException("POST"));

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.METHOD_NOT_ALLOWED);
        assertThat(resp.getBody().getCode()).isEqualTo("METHOD_NOT_ALLOWED");
    }

    @Test
    void conflictDoesNotLeakInternals() {
        ResponseEntity<ApiResponse<Void>> resp =
                handler.handleConflict(new DataIntegrityViolationException("duplicate key value violates unique constraint \"uq_x\""));

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(resp.getBody().getCode()).isEqualTo("CONFLICT");
        assertThat(resp.getBody().getError()).doesNotContain("unique constraint");
    }

    @Test
    void unexpectedIsGenericAndDoesNotLeak() {
        ResponseEntity<ApiResponse<Void>> resp =
                handler.handleUnexpected(new RuntimeException("NullPointer in PaymentService line 42"));

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(resp.getBody().getCode()).isEqualTo("INTERNAL_ERROR");
        assertThat(resp.getBody().getError()).doesNotContain("PaymentService");
        assertThat(resp.getBody().getError()).contains("Something went wrong");
    }
}
